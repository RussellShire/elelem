---
# noinspection YAMLUnresolvedAlias
globs: **/*_test.go
---

# Go Testing

## Framework

Use the standard `testing` package for new projects or projects without an established applicable framework. Preserve the established applicable framework in existing projects. For advanced assertions, use `testify/assert` or `testify/require` if the project already uses it. Do not introduce a second runner or migrate frameworks without an approved migration. A framework preference does not authorise dependency installation. When multiple frameworks are established, use project context or ask the user rather than assuming a hierarchy. Framework-specific API instructions and examples below apply only when using the named framework. In an existing project with a different established applicable framework, use its equivalent APIs rather than changing frameworks to follow an example.

## File and Function Naming

- Test files: `<module>_test.go` in the same package (or `<module>_test` for external tests)
- Test functions: `func TestFeature(t *testing.T)` or `func TestFeature_Scenario(t *testing.T)` using descriptive phrases
- Benchmark functions: `func BenchmarkFeature(b *testing.B)`
- Example functions: `func ExampleFeature()` for documentation

## Structure

- Use subtests with `t.Run("scenario", func(t *testing.T) {...})` to group related tests
- Table-driven tests for testing multiple inputs/outputs
- Use `t.Helper()` in test helper functions to improve error reporting
- Use `t.Parallel()` when tests can run concurrently

## Assertions

- Use `t.Fatalf()` when a failure means later assertions are meaningless
- Use `t.Errorf()` when you want to report an error and continue
- When using `testify`, prefer `testify/require` for fatal assertions and `testify/assert` for non-fatal assertions
- Format error messages: `"got %v, want %v"` or similar

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: network (use `httptest`), file system (`t.TempDir()`), time, randomness
- Use interfaces to enable testing without heavy mocking frameworks
