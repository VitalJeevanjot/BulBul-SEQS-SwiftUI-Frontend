# AGENTS.md

## Project Notes

- This is a SwiftUI frontend that configures Amplify in `BulBul-SEQS/BulBul_SEQSApp.swift` with `Amplify.configure(with: .amplifyOutputs)`.
- The app must support both iOS and macOS. Keep shared SwiftUI code portable across both platforms, guard platform-only APIs with appropriate conditional compilation, and do not fix one platform by breaking the other.
- Before changing frontend API/auth behavior, inspect `BulBul-SEQS/AmplifyWorks/amplify_outputs.json`.
- Use that file to confirm the frontend is calling the correct backend: check the GraphQL endpoint under `data.url`, the AWS region, auth mode, model names, custom operations, and expected auth rules.
- Keep `BulBul-SEQS/AmplifyWorks/amplify_outputs.json` tracked unless the project explicitly moves to a different Amplify configuration flow.
- Do not commit local secrets such as `BulBul-SEQS/environment_vars.plist`, `BulBul-SEQS/Secrets.plist`, or private `.xcconfig` files.
- Use the latest SwiftUI APIs supported by the project deployment targets. Keep shared views native and portable across iOS and macOS, with platform-only data collection or presentation guarded by conditional compilation.
- Every backend operation whose Amplify argument list contains `fraudPreventionHeaders` must create fresh HMRC fraud-prevention header data immediately before the request and pass the serialized headers in that field. Treat mobile and desktop as different HMRC profiles: iOS uses `MOBILE_APP_VIA_SERVER` and must not send `Gov-Client-MAC-Addresses`; macOS uses `DESKTOP_APP_VIA_SERVER`, must send `Gov-Client-MAC-Addresses`, and includes the OS user in `Gov-Client-User-IDs`. Preserve the Keychain-backed `Gov-Client-Device-ID`, and keep unsupported vendor values explicit rather than silently omitting the header names.

## Verification

- For frontend API changes, compare any `Amplify.API` request names, decode paths, model names, and auth assumptions against `BulBul-SEQS/AmplifyWorks/amplify_outputs.json`.
- For requests with `fraudPreventionHeaders`, verify both iOS and macOS header collectors still match HMRC's current mobile-app-via-server and desktop-app-via-server guidance.
- For UI or project-setting changes, build the app for both an iOS Simulator destination and a macOS destination when the local Xcode installation supports them.
