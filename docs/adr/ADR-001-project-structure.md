# ADR-001: Project Structure

- **Status:** Accepted
- **Date:** 2026-08-05
- **Decision Makers:** GetSetWell Engineering Team

---

# Context

GetSetWell is being developed as a production-ready mobile application with the goal of releasing an MVP within 1–2 months while maintaining a codebase that can scale beyond the MVP.

The project should be easy for future developers to understand and contribute to without requiring a major refactor. New developers should be able to clone the repository, create feature branches, and contribute through pull requests.

To achieve this, the project requires a clear, modular folder structure that separates application layers and avoids tightly coupled code.

---

# Decision

The project will adopt the following folder structure:

```text
lib/
├── app/
│   ├── app.dart
│   └── app_theme.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── network/
│   ├── services/
│   ├── theme/
│   └── utils/
│
├── features/
│
├── shared/
│   ├── models/
│   └── widgets/
│
├── l10n/
│
└── main.dart
```

---

# Rationale

### app/

Contains application-level configuration.

Examples:

- MaterialApp
- Theme
- Routing
- Global configuration

---

### core/

Contains reusable infrastructure that is independent of any specific feature.

Examples:

- Colors
- Typography
- Constants
- Network layer
- Services
- Utilities
- Error handling

Nothing inside `core` should depend on a feature.

---

### features/

Contains all business features.

Examples:

- Authentication
- Home
- Trainers
- Booking
- Profile

Each feature should be self-contained whenever possible.

---

### shared/

Contains reusable code shared across multiple features.

Examples:

- Common widgets
- Shared models
- Generic UI components

---

### l10n/

Contains localization files and generated localization code.

---

### main.dart

Application entry point.

Responsibilities:

- Initialize Flutter
- Initialize dependencies
- Launch the application

No business logic should exist here.

---

# Consequences

## Advantages

- Clear separation of responsibilities.
- Easier onboarding for new developers.
- Scalable as the application grows.
- Encourages feature-based development.
- Reduces coupling between modules.
- Easier code reviews and maintenance.

## Trade-offs

- Slightly more folders during the early MVP stage.
- Requires discipline when deciding where new files belong.

These trade-offs are acceptable because they improve long-term maintainability.

---

# Alternatives Considered

### Flat structure

Store everything directly under `lib/`.

Rejected because it becomes difficult to navigate as the project grows.

---

### Layer-based architecture

Separate folders such as:

- screens
- widgets
- providers
- services

Rejected because features become scattered across multiple directories, making it harder to work on a single feature in isolation.

---

# Status

Accepted.

This structure will be used throughout the GetSetWell project unless a future Architecture Decision Record supersedes this decision.