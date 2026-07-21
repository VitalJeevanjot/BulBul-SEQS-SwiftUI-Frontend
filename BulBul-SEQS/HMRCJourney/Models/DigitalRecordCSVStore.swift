import Foundation
import SwiftData

enum DigitalRecordCSVStore {
    private static let header = [
        "Index", "Date", "Sample bank description", "Amount", "Transaction type",
        "Possible HMRC category", "Confidence in classification", "Disallowable Amount",
    ]

    @MainActor
    static func importFile(
        at sourceURL: URL,
        for business: StoredBusiness,
        modelContext: ModelContext
    ) throws -> Int {
        guard business.digitalRecords.isEmpty else { throw CSVStoreError.recordsAlreadyExist }

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: sourceURL)
        guard let contents = String(data: data, encoding: .utf8) else { throw CSVStoreError.invalidEncoding }
        let records = try records(fromCSV: contents)
        guard !records.isEmpty else { throw CSVStoreError.noRecords }

        let destination = try copiedFileDestination(sourceURL: sourceURL, business: business)
        try FileManager.default.copyItem(at: sourceURL, to: destination.url)

        do {
            for record in records {
                modelContext.insert(record)
                business.digitalRecords.append(record)
            }
            business.importedCSVRelativePath = destination.relativePath
            business.updatedAt = Date()
            try modelContext.save()
            return records.count
        } catch {
            try? FileManager.default.removeItem(at: destination.url)
            modelContext.rollback()
            throw error
        }
    }

    @MainActor
    static func deleteAll(for business: StoredBusiness, modelContext: ModelContext) throws {
        for record in Array(business.digitalRecords) { modelContext.delete(record) }
        business.digitalRecords.removeAll()
        try removeImportedCopy(for: business)
        business.importedCSVRelativePath = nil
        business.updatedAt = Date()
        try modelContext.save()
    }

    @MainActor
    static func delete(
        _ record: DigitalRecord,
        from business: StoredBusiness,
        modelContext: ModelContext
    ) throws {
        if business.digitalRecords.count <= 1 {
            try deleteAll(for: business, modelContext: modelContext)
            return
        }
        business.digitalRecords.removeAll { $0.recordID == record.recordID }
        modelContext.delete(record)
        business.updatedAt = Date()
        try modelContext.save()
    }

    static func records(fromCSV contents: String) throws -> [DigitalRecord] {
        let rows = CSVParser.rows(from: contents)
        guard let header = rows.first else { throw CSVStoreError.noRecords }
        let normalizedHeader = header.map { $0.replacingOccurrences(of: "\u{feff}", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
        guard normalizedHeader == self.header else { throw CSVStoreError.invalidHeader(self.header) }

        return try rows.dropFirst().enumerated().compactMap { offset, columns in
            guard columns.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
            guard columns.count == self.header.count else { throw CSVStoreError.invalidColumnCount(row: offset + 2) }

            let row = offset + 2
            guard let index = Int(columns[0].trimmingCharacters(in: .whitespaces)) else { throw CSVStoreError.invalidValue(row: row, column: self.header[0]) }
            guard let date = CSVDateParser.date(from: columns[1]) else { throw CSVStoreError.invalidValue(row: row, column: self.header[1]) }
            guard let amount = decimal(from: columns[3]) else { throw CSVStoreError.invalidValue(row: row, column: self.header[3]) }
            guard let transactionType = DigitalRecordTransactionType(rawValue: columns[4].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw CSVStoreError.invalidValue(row: row, column: self.header[4])
            }
            guard let category = HMRCCategory(rawValue: columns[5].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw CSVStoreError.invalidValue(row: row, column: self.header[5])
            }
            guard var confidence = decimal(from: columns[6]) else { throw CSVStoreError.invalidValue(row: row, column: self.header[6]) }
            if columns[6].contains("%") || confidence > 1 { confidence /= 100 }
            guard (0...1).contains(confidence) else { throw CSVStoreError.invalidValue(row: row, column: self.header[6]) }
            guard let disallowable = decimal(from: columns[7]), disallowable >= 0, disallowable <= abs(amount) else {
                throw CSVStoreError.invalidValue(row: row, column: self.header[7])
            }

            return DigitalRecord(
                index: index,
                date: date,
                bankDescription: columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                transactionType: transactionType,
                hmrcCategory: category,
                classificationConfidence: confidence,
                disallowableAmount: disallowable
            )
        }
    }

    static func csv(from records: [DigitalRecord]) -> String {
        let rows = records.map { record in
            [
                String(record.index),
                CSVDateParser.string(from: record.date),
                record.bankDescription,
                formattedDecimal(record.amount),
                record.transactionTypeRawValue,
                record.hmrcCategoryRawValue,
                formattedDecimal(record.classificationConfidence),
                formattedDecimal(record.disallowableAmount),
            ]
            .map(escapedCSVField)
            .joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + rows).joined(separator: "\n") + "\n"
    }

    private static func formattedDecimal(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func escapedCSVField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func decimal(from value: String) -> Double? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
        return Double(cleaned)
    }

    private static func copiedFileDestination(
        sourceURL: URL,
        business: StoredBusiness
    ) throws -> (url: URL, relativePath: String) {
        let relativeDirectory = "ImportedDigitalRecords/\(business.recordID.uuidString)"
        let directory = try applicationSupportURL().appending(path: relativeDirectory, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeName = sourceURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(UUID().uuidString)-\(safeName).csv"
        return (directory.appending(path: fileName), "\(relativeDirectory)/\(fileName)")
    }

    private static func removeImportedCopy(for business: StoredBusiness) throws {
        guard let relativePath = business.importedCSVRelativePath else { return }
        let fileURL = try applicationSupportURL().appending(path: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func applicationSupportURL() throws -> URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CSVStoreError.applicationSupportUnavailable
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private enum CSVParser {
    static func rows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if character == "\"" {
                if insideQuotes, next < text.endIndex, text[next] == "\"" {
                    field.append("\"")
                    index = text.index(after: next)
                    continue
                }
                insideQuotes.toggle()
            } else if character == ",", !insideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !insideQuotes {
                row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
            index = next
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
            rows.append(row)
        }
        return rows
    }
}

private enum CSVDateParser {
    private static let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy"]

    static func date(from value: String) -> Date? {
        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_GB_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) { return date }
        }
        return nil
    }

    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = formats[0]
        return formatter.string(from: date)
    }
}

private enum CSVStoreError: LocalizedError {
    case recordsAlreadyExist
    case invalidEncoding
    case noRecords
    case invalidHeader([String])
    case invalidColumnCount(row: Int)
    case invalidValue(row: Int, column: String)
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .recordsAlreadyExist: "Delete all existing records before importing another CSV."
        case .invalidEncoding: "The CSV must use UTF-8 text encoding."
        case .noRecords: "The CSV contains no digital records."
        case .invalidHeader(let headers): "The CSV header must be: \(headers.joined(separator: ", "))."
        case .invalidColumnCount(let row): "CSV row \(row) does not contain exactly 8 columns."
        case .invalidValue(let row, let column): "CSV row \(row) has an invalid value in “\(column)”."
        case .applicationSupportUnavailable: "The app’s Application Support directory is unavailable."
        }
    }
}
