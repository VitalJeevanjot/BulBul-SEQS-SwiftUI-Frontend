import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DigitalRecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var business: StoredBusiness

    @State private var sortOrder = [KeyPathComparator(\DigitalRecord.index)]
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = DigitalRecordsCSVDocument()
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isConfirmingDeleteAll = false

    private var records: [DigitalRecord] {
        business.digitalRecords.sorted(using: sortOrder)
    }

    private var dateRange: String? {
        guard let start = business.digitalRecords.map(\.date).min(),
              let end = business.digitalRecords.map(\.date).max() else { return nil }
        return "\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if business.digitalRecords.isEmpty {
                ContentUnavailableView {
                    Label("No digital records", systemImage: "tablecells.badge.ellipsis")
                } description: {
                    Text("Import the 8-column BulBul SEQS CSV to create editable records for this business.")
                } actions: {
                    Button("Import CSV", systemImage: "square.and.arrow.down") { isImporting = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                HStack {
                    if let dateRange {
                        Label(dateRange, systemImage: "calendar")
                            .font(.headline)
                    }
                    Spacer()
                    Text("\(business.digitalRecords.count) records")
                        .foregroundStyle(.secondary)
                    Button("Export CSV", systemImage: "square.and.arrow.up") {
                        exportDocument = DigitalRecordsCSVDocument(contents: DigitalRecordCSVStore.csv(from: records))
                        isExporting = true
                    }
                    .buttonStyle(.bordered)
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                GeometryReader { geometry in
                    ScrollView(.horizontal) {
                        recordsTable(width: max(geometry.size.width, 1400))
                    }
                }
                .frame(minHeight: 460)

                Button("Delete All Records", systemImage: "trash", role: .destructive) {
                    isConfirmingDeleteAll = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
            importCSV(result)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "\(business.businessID)-Digital-Records.csv"
        ) { result in
            switch result {
            case .success:
                statusMessage = "Exported \(records.count) records."
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Delete all digital records?",
            isPresented: $isConfirmingDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { deleteAll() }
        } message: {
            Text("This removes the SwiftData records and the app’s private CSV copy. Your original CSV is not changed.")
        }
        .alert("Digital records", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func recordsTable(width: CGFloat) -> some View {
        Table(records, sortOrder: $sortOrder) {
            TableColumn("Index", value: \.index) { RecordIndexCell(record: $0) }
                .width(min: 70, ideal: 80)
            TableColumn("Date", value: \.date) { RecordDateCell(record: $0) }
                .width(min: 130, ideal: 150)
            TableColumn("Sample bank description", value: \.bankDescription) { RecordDescriptionCell(record: $0) }
                .width(min: 220, ideal: 300)
            TableColumn("Amount", value: \.amount) { RecordAmountCell(record: $0) }
                .width(min: 110, ideal: 130)
            TableColumn("Transaction type", value: \.transactionTypeRawValue) { RecordTypeCell(record: $0) }
                .width(min: 160, ideal: 180)
            TableColumn("Possible HMRC category", value: \.hmrcCategoryRawValue) { RecordCategoryCell(record: $0) }
                .width(min: 230, ideal: 280)
            TableColumn("Confidence", value: \.classificationConfidence) { RecordConfidenceCell(record: $0) }
                .width(min: 120, ideal: 140)
            TableColumn("Disallowable Amount", value: \.disallowableAmount) { RecordDisallowableCell(record: $0) }
                .width(min: 150, ideal: 170)
            TableColumn("") { record in
                Button("Delete", systemImage: "trash", role: .destructive) { delete(record) }
                    .labelStyle(.iconOnly)
            }
            .width(54)
        }
        .frame(width: width)
        .frame(minHeight: 460)
    }

    private func importCSV(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let count = try DigitalRecordCSVStore.importFile(at: url, for: business, modelContext: modelContext)
            statusMessage = "Imported \(count) records and saved a private CSV copy."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ record: DigitalRecord) {
        do {
            try DigitalRecordCSVStore.delete(record, from: business, modelContext: modelContext)
            statusMessage = business.digitalRecords.isEmpty ? nil : "Record deleted."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAll() {
        do {
            try DigitalRecordCSVStore.deleteAll(for: business, modelContext: modelContext)
            statusMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DigitalRecordsCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var contents = ""

    init(contents: String = "") {
        self.contents = contents
    }

    init(configuration: ReadConfiguration) throws {
        contents = configuration.file.regularFileContents.map {
            String(decoding: $0, as: UTF8.self)
        } ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(contents.utf8))
    }
}

private struct RecordIndexCell: View {
    @Bindable var record: DigitalRecord
    var body: some View { TextField("Index", value: $record.index, format: .number).onSubmit { record.touch() } }
}

private struct RecordDateCell: View {
    @Bindable var record: DigitalRecord
    var body: some View {
        DatePicker("Date", selection: $record.date, displayedComponents: .date)
            .labelsHidden()
            .onChange(of: record.date) { _, _ in record.touch() }
    }
}

private struct RecordDescriptionCell: View {
    @Bindable var record: DigitalRecord
    var body: some View { TextField("Description", text: $record.bankDescription).onSubmit { record.touch() } }
}

private struct RecordAmountCell: View {
    @Bindable var record: DigitalRecord
    var body: some View {
        TextField("Amount", value: $record.amount, format: .number.precision(.fractionLength(2)))
            .onSubmit { record.normalizeEditableValues() }
    }
}

private struct RecordTypeCell: View {
    @Bindable var record: DigitalRecord
    var body: some View {
        Picker("Transaction type", selection: $record.transactionTypeRawValue) {
            ForEach(DigitalRecordTransactionType.allCases) { type in Text(type.title).tag(type.rawValue) }
        }
        .labelsHidden()
        .onChange(of: record.transactionTypeRawValue) { _, _ in record.touch() }
    }
}

private struct RecordCategoryCell: View {
    @Bindable var record: DigitalRecord
    @State private var isSelecting = false

    var body: some View {
        Button(record.hmrcCategory.title) { isSelecting = true }
            .buttonStyle(.plain)
            .lineLimit(2)
            .sheet(isPresented: $isSelecting) {
                SearchableHMRCCategoryPicker(selection: Binding(
                    get: { record.hmrcCategory },
                    set: { record.hmrcCategory = $0 }
                ))
            }
    }
}

private struct RecordConfidenceCell: View {
    @Bindable var record: DigitalRecord
    var body: some View {
        TextField("Confidence", value: $record.classificationConfidence, format: .percent.precision(.fractionLength(0)))
            .onSubmit { record.normalizeEditableValues() }
    }
}

private struct RecordDisallowableCell: View {
    @Bindable var record: DigitalRecord
    var body: some View {
        TextField("Disallowable", value: $record.disallowableAmount, format: .number.precision(.fractionLength(2)))
            .onSubmit { record.normalizeEditableValues() }
    }
}

struct SearchableHMRCCategoryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: HMRCCategory
    @State private var searchText = ""

    private var options: [HMRCCategory] {
        guard !searchText.isEmpty else { return HMRCCategory.allCases }
        return HMRCCategory.allCases.filter {
            $0.rawValue.localizedStandardContains(searchText) || $0.title.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(options) { category in
                Button {
                    selection = category
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(category.title)
                            Text(category.rawValue).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selection == category { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search all 30 HMRC keys")
            .navigationTitle("HMRC category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
#if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
#endif
    }
}
