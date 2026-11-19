---
# noinspection YAMLUnresolvedAlias
globs: **/*.rs
---

# Rust Testing

## Framework

Use the built-in test framework (`#[test]` and `#[cfg(test)]`) for new projects or projects without an established applicable framework. Preserve the established applicable framework in existing projects. Use `rstest` for advanced parameterised tests in new projects or when the project already uses it. Do not introduce a second runner or migrate frameworks without an approved migration. A framework preference does not authorise dependency installation. When multiple frameworks are established, use project context or ask the user rather than assuming a hierarchy. Framework-specific API instructions and examples below apply only when using the named framework. In an existing project with a different established applicable framework, use its equivalent APIs rather than changing frameworks to follow an example.

## File and Function Naming

- Tests live in a `tests` module at the bottom of each file: `#[cfg(test)] mod tests { ... }`
- Integration tests live in `tests/` directory at the project root
- Test functions: `#[test] fn test_feature_scenario()` using descriptive names
- Benchmark functions: use the `criterion` crate in new projects or when the established project already uses it; do not replace existing benchmark tools or install it without approved dependency changes

## Structure

- One assertion concept per test; multiple `assert!` lines are fine if verifying one behaviour
- Use `#[should_panic(expected = "message")]` for tests that expect panics
- Use `Result<(), E>` return type for tests with `?` operator
- Group related tests in nested `mod` blocks within the tests module
- Use `rstest` for parameterised tests in new projects or when the project already uses it; in existing projects, preserve the established applicable framework rather than introducing `rstest` solely to avoid copy-pasting

## Assertions

- Use `assert_eq!(left, right)` for equality checks (shows both values on failure)
- Use `assert_ne!(left, right)` for inequality
- Use `assert!(condition)` for boolean checks
- Use `assert!(result.is_ok())` or `assert!(result.is_err())` for Result checks
- For custom error messages: `assert_eq!(left, right, "context: {}", extra_info)`

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: network (use test servers), file system (`tempfile`), time (`mock_instant`), randomness
- Use traits and dependency injection for testability
- Prefer fakes (real implementations with test configuration) over mocks when possible
