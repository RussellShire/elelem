---
# noinspection YAMLUnresolvedAlias
globs: **/*.test.js, **/*.spec.js, **/tests/**/*.js, **/jest.config.js, **/vitest.config.js
---

# JavaScript Testing

## Framework

Use `vitest` for new projects or projects without an established applicable framework (fast, ESM-native, compatible with Jest). Use `jest` if the project already uses it. Preserve the established applicable framework, including Mocha/Chai, for new code in existing projects. Do not introduce a second runner or migrate frameworks without an approved migration. A framework preference does not authorise dependency installation. When multiple frameworks are established, use project context or ask the user rather than assuming a hierarchy. Framework-specific API instructions and examples below apply only when using the named framework. In an existing project with a different established applicable framework, use its equivalent APIs rather than changing frameworks to follow an example.

## File and Function Naming

- Test files: `<module>.test.js` (preferred) or `<module>.spec.js`
- Test functions: `test('should do something specific', () => {})` or `it('does something', () => {})`
- Group related tests with `describe('Feature', () => {})`

## Structure

- One assertion concept per test
- Use `beforeEach`/`afterEach` for common set-up/teardown
- Use `describe` blocks to organise related tests
- Prefer test-specific set-up over shared state between tests
- For Jest or Vitest, use parameterised tests (`test.each`) rather than copy-pasting

## Assertions

- For Jest or Vitest, use `expect(value).toBe(expected)` for assertions
- For Jest or Vitest objects, use `.toEqual()` for deep equality and `.toBe()` for reference equality
- For async assertions in Jest or Vitest, use `await expect(promise).resolves.toBe(value)` or `await expect(promise).rejects.toThrow()`
- For Jest or Vitest, chain matchers for clarity with `expect(arr).toHaveLength(3)`

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: HTTP requests (`msw`), file system and DOM
- For Vitest timers, use `vi.useFakeTimers`
- Use dependency injection to make code testable without heavy mocking
