## Stack

- **iOS SDK 26**
- **Swift 6 language mode**
- **SwiftUI** as the primary UI layer, with **UIKit islands** (`UIViewRepresentable` / `UIViewControllerRepresentable`) where UIKit is the better fit
- **SwiftData** for persistence
- **Swift Testing** for tests

Target Swift 6 language mode and concurrency rules. Do not suppress concurrency diagnostics.

## Project

XcodeGen generates `Haystack.xcodeproj` from `project.yml`. Source directories are file-system synchronized, so new files under existing target folders are picked up automatically. Do not edit the generated project.

Use `make` for all project operations. Do not invoke `xcodegen` or `xcodebuild` directly.

| Target | What it does |
| --- | --- |
| `make generate` | Regenerates `Haystack.xcodeproj` from `project.yml` |
| `make build` | Debug simulator build |
| `make test` | Run tests on the simulator |
| `make launch` | Build, install, and launch on the simulator |
| `make archive` | Release device archive |
| `make clean` | Removes the generated project, derived data, and archive |

After changing `project.yml`, run `make generate`. Simulator name comes from `.env` (`SIMULATOR`).

## Comments

Do not comment code.

Exceptions:

- **Public interfaces**: document public types, methods, properties, and other API surface that callers outside the defining module need to understand.
- **`TODO:` placeholders** for work deferred to a later phase. Prefer a `TODO` over generating the full implementation when the current phase does not need it.
