# Initial Repo Setup Checkpoint

Date: 2026-07-19

## What Has Been Done

- Initialized this folder as a Git repository.
- Added a Swift/Xcode-focused `.gitignore`.
- Kept local generated/user files ignored, including `.DS_Store`, Xcode `xcuserdata`, and `BulBul-SEQS/environment_vars.plist`.
- Explicitly kept `BulBul-SEQS/AmplifyWorks/amplify_outputs.json` trackable because the SwiftUI app configures Amplify with `.amplifyOutputs`.
- Added `AGENTS.md` with instructions to inspect `BulBul-SEQS/AmplifyWorks/amplify_outputs.json` before changing frontend API/auth behavior.
- Restored the local ignored `BulBul-SEQS/environment_vars.plist` with the HMRC config keys required by `GlobalConstants.swift`.
- Created the initial commit on `main`: `6922414 Initial SwiftUI project`.
- Created and pushed the private GitHub repository:
  `https://github.com/VitalJeevanjot/BulBul-SEQS-SwiftUI-Frontend`

## Current Branch Purpose

This branch captures the project state after initial Git/GitHub setup and adds this note as a checkpoint.

## Current Amplify Outputs Change

At the time this checkpoint branch was made, `BulBul-SEQS/AmplifyWorks/amplify_outputs.json` had local changes adding custom query output metadata for:

- `listBusinesses`
- `retrieveBusinessDetails`

Future frontend API work should compare any `Amplify.API` request names, variables, decode paths, model names, and auth assumptions against that outputs file before making call changes.
