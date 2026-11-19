---
# noinspection YAMLUnresolvedAlias
globs: **/*.test.ts, **/*.spec.ts, **/*.test.tsx, **/*.spec.tsx, **/tests/**/*.ts, **/jest.config.ts, **/vitest.config.ts
---

# TypeScript Testing

## Framework

Use `vitest` for new projects or projects without an established applicable framework (fast, native ESM and TypeScript support). Use `jest` with `ts-jest` if the project already uses it. Preserve the established applicable framework in existing projects. Do not introduce a second runner or migrate frameworks without an approved migration. A framework preference does not authorise dependency installation. When multiple frameworks are established, use project context or ask the user rather than assuming a hierarchy. Framework-specific API instructions and examples below apply only when using the named framework. In an existing project with a different established applicable framework, use its equivalent APIs rather than changing frameworks to follow an example.

## File and Function Naming

- Test files: `<module>.test.ts` (preferred) or `<module>.spec.ts`
- Test functions: `test('should do something specific', () => {})` or `it('does something', () => {})`
- Group related tests with `describe('Feature', () => {})`
- Type your test data and mocks for better safety

## Structure

- One assertion concept per test
- Use `beforeEach`/`afterEach` for common set-up/teardown
- Use `describe` blocks to organise related tests
- Prefer test-specific set-up over shared state between tests
- For Jest or Vitest, use parameterised tests (`test.each`) rather than copy-pasting
- Type your fixtures and test data properly

## Assertions

- For Jest or Vitest, use `expect(value).toBe(expected)` for assertions
- For Jest or Vitest objects, use `.toEqual()` for deep equality and `.toBe()` for reference equality
- For async assertions in Jest or Vitest, use `await expect(promise).resolves.toBe(value)` or `await expect(promise).rejects.toThrow()`
- Use type assertions sparingly; prefer proper typing of test data
- Leverage TypeScript to catch type mismatches at compile time

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: HTTP requests (`msw`), file system and DOM
- For Vitest timers, use `vi.useFakeTimers`
- Use dependency injection with typed interfaces to make code testable
- Type your mocks properly with the same interfaces as the real implementations
