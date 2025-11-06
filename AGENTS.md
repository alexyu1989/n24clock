# Repository Guidelines

## Project Structure & Module Organization
The app lives in `n24clock/`, with SwiftUI surfaces in files such as `ContentView.swift`, `OnboardingGuideView.swift`, and `ClockDriftInfoView.swift`. Domain logic sits in `BiologicalClock.swift`, while persistence and session state are handled by `ClockSettings.swift` via `UserDefaults`. Shared visual assets are stored in `Assets.xcassets`; the Xcode project configuration resides in `n24clock.xcodeproj`.

## Build, Test, and Development Commands
- `open n24clock.xcodeproj` opens the workspace in Xcode for interactive development.
- `xcodebuild -scheme n24clock -destination 'platform=iOS Simulator,name=iPhone 15' build` performs a clean command-line build.
- `xcodebuild test -scheme n24clock -destination 'platform=iOS Simulator,name=iPhone 15'` executes the XCTest suite once it exists; run after adding or updating tests.

## Coding Style & Naming Conventions
Use Swift 5 conventions with four-space indentation and trailing commas where Xcode applies them. Keep types and protocols in UpperCamelCase, functions and stored properties in lowerCamelCase, and prefer explicit access control. Group related helpers with `// MARK:` comments, mirroring the patterns already present in `BiologicalClock.swift`. Favor structs and value semantics for domain calculations and keep SwiftUI views declarative and composable.

## Testing Guidelines
Add unit tests in a `n24clockTests` target for every change that touches `BiologicalClock` calculations or `ClockSettings` persistence behavior. Name test files after the type under test (e.g., `BiologicalClockTests.swift`) and use descriptive method names prefixed with `test`. When adding UI that depends on time, isolate logic behind injectable clocks so it can be exercised in XCTest without real timers. Run `xcodebuild test ...` locally before pushing.

## Commit & Pull Request Guidelines
Follow the existing history’s concise, imperative subject lines (e.g., `Add drift info view`). Keep each commit scoped to a logical unit and include migration notes in the body when touching persistence. Pull requests should summarize behavior changes, list manual test steps, and attach simulator screenshots for visual updates. Link to tracking issues and call out any remaining follow-up tasks or strings needing localization.

## Security & Configuration Tips
Avoid hard-coding personal calendars or secrets; all persisted values currently live in `UserDefaults`, so document any new keys in `ClockSettings`. When adding integrations, store tokens in the developer environment and gate debug-only features behind conditional compilation flags to keep release builds clean.
