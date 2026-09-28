# Haystack

Haystack is an iOS envelope-budgeting app: manage the money you have, and plan what that money is for. It is modeled on YNAB.

## Components

Account management and planning have to stay in sync because spending is categorized.

**Account management** is what money you have.

- **Accounts** — where the money is
- **Transactions** — money in, money out, or transfers between accounts

**Planning** is giving that money a job.

- **Plans** — the budget you are working in
- **Categories** — the envelopes in a plan
- **Assignments** — moving money you already have into a category for a month
- **Targets** — how much a category should have, and by when

## Architecture

The code follows DDD, with a clean split between layers:

- **Domain** — layers, aggregates, invariants, and value objects.
- **Application** — use cases that orchestrate the domain.
- **Infrastructure** — persistence and other adapters. Writes are isolated to a `ModelActor`.
- **Presentation** — SwiftUI, with UIKit only where it is the better fit.

Views do not use SwiftData directly: reads come through query interfaces, loaded from the environment inside `.task` and kept in view state. Writes go through the application layer. Domain and application code never depends on `MainActor`.
