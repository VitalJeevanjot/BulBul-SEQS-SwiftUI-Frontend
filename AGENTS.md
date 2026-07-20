# AGENTS.md

## Project Notes

- This is a SwiftUI frontend that configures Amplify in `BulBul-SEQS/BulBul_SEQSApp.swift` with `Amplify.configure(with: .amplifyOutputs)`.
- The app must support both iOS and macOS. Keep shared SwiftUI code portable across both platforms, guard platform-only APIs with appropriate conditional compilation, and do not fix one platform by breaking the other.
- Before changing frontend API/auth behavior, inspect `BulBul-SEQS/AmplifyWorks/amplify_outputs.json`.
- Use that file to confirm the frontend is calling the correct backend: check the GraphQL endpoint under `data.url`, the AWS region, auth mode, model names, custom operations, and expected auth rules.
- Keep `BulBul-SEQS/AmplifyWorks/amplify_outputs.json` tracked unless the project explicitly moves to a different Amplify configuration flow.
- Do not commit local secrets such as `BulBul-SEQS/environment_vars.plist`, `BulBul-SEQS/Secrets.plist`, or private `.xcconfig` files.

## Verification

- For frontend API changes, compare any `Amplify.API` request names, decode paths, model names, and auth assumptions against `BulBul-SEQS/AmplifyWorks/amplify_outputs.json`.
- For UI or project-setting changes, build the app for both an iOS Simulator destination and a macOS destination when the local Xcode installation supports them.
