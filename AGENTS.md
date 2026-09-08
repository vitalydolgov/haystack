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
| `make test ONLY=<SuiteName>` | Run a single test suite |
| `make launch` | Build, install, and launch on the simulator |
| `make purge` | Uninstalls the app from the simulator, dropping its data |
| `make archive` | Release device archive |
| `make clean` | Removes the generated project, derived data, and archive |

After changing `project.yml`, run `make generate`. Simulator name comes from `.env` (`SIMULATOR`).

## Conventions

### `@Transactional`

A body macro on mutating use-case `execute` methods. It wraps the method body in `unitOfWork.perform { store in ... }`, so the body can use `store` (accounts and transactions repositories) even though `store` is not a parameter.

Do not call `unitOfWork.perform` by hand in use cases. Annotate `execute` with `@Transactional` and write against `store` directly.

## Testing

Do not write tests during implementation. Tests are a later pass, only when requested.

Each test asserts only the behavior in its name. Do not snapshot every field after an operation unless that is the point of the test.

**Domain.** Exercise types in memory. Cover identity and field invariants, then group remaining tests by operation. Inside each group, put the happy path first.

**Application.** One suite per use case, against in-memory fakes. Put the happy path first and leave it unmarked, then `// MARK: Validation`, then `// MARK: Errors`.

**Persistence.** Exercise the real store. Group tests by operation. Inside each group, put the happy path first. A round-trip of all fields is the one case that should snapshot every field.

## Comments

Do not comment code.

Exceptions:

- **Public interfaces**: document public types, methods, properties, and other API surface that callers outside the defining module need to understand.
- **`TODO:` placeholders** for work deferred to a later phase. Prefer a `TODO` over generating the full implementation when the current phase does not need it.
- **Tests**: `// MARK:` as described in Testing.

## Repository

- Conventional commit prefixes (feat, fix, test, refactor, perf, style, docs, build).
- Subject-only: omit body and footer unless explaining a breaking change or complex rationale.
- No period at the end of the subject.
