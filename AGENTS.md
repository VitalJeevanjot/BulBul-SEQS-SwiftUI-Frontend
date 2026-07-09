# AGENTS.md

## Project Notes

- This is a SwiftUI frontend that configures Amplify in `BulBul-SEQS/BulBul_SEQSApp.swift` with `Amplify.configure(with: .amplifyOutputs)`.
- Before changing frontend API/auth behavior, inspect `BulBul-SEQS/AmplifyWorks/amplify_outputs.json`.
- Use that file to confirm the frontend is calling the correct backend: check the GraphQL endpoint under `data.url`, the AWS region, auth mode, model names, custom operations, and expected auth rules.
- Keep `BulBul-SEQS/AmplifyWorks/amplify_outputs.json` tracked unless the project explicitly moves to a different Amplify configuration flow.
- Do not commit local secrets such as `BulBul-SEQS/environment_vars.plist`, `BulBul-SEQS/Secrets.plist`, or private `.xcconfig` files.

## Verification

- For frontend API changes, compare any `Amplify.API` request names, decode paths, model names, and auth assumptions against `BulBul-SEQS/AmplifyWorks/amplify_outputs.json`.

