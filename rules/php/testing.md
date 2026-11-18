---
# noinspection YAMLUnresolvedAlias
globs: **/tests/**/*.php, **/*Test.php, **/phpunit.xml
---

# PHP Testing

## Framework

Use `PHPUnit` for new projects or projects without an established applicable framework. Use `Pest` for BDD-style testing if the project already uses it, and preserve the established applicable framework in existing projects. Do not introduce a second runner or migrate frameworks without an approved migration. A framework preference does not authorise dependency installation. When multiple frameworks are established, use project context or ask the user rather than assuming a hierarchy. Framework-specific API instructions and examples below apply only when using the named framework. In an existing project with a different established applicable framework, use its equivalent APIs rather than changing frameworks to follow an example.

## File and Function Naming

- Test files: `<Class>Test.php` in the `tests/` directory, mirroring the `src/` structure
- For PHPUnit, define test classes as `class UserTest extends TestCase`
- For PHPUnit, name test methods with descriptive phrases such as `public function testFeatureScenario()` or `public function test_feature_scenario()`
- For PHPUnit, use data providers for parameterised tests: `#[DataProvider('providerName')]`

## Structure

- One assertion concept per test
- For PHPUnit, use `setUp()` and `tearDown()` for common test fixtures
- Prefer test-specific set-up over shared mutable state between tests
- For PHPUnit, use data providers (`#[DataProvider]`) rather than copy-pasting tests
- Organise tests in directories mirroring your source code structure

## Assertions

- For PHPUnit, use specific assertions: `assertSame()` for identity and `assertEquals()` for equality
- For PHPUnit exceptions, use `$this->expectException(InvalidArgumentException::class)`
- For PHPUnit string assertions, use `assertStringContainsString()`, `assertStringStartsWith()`, etc.
- For PHPUnit array assertions, use `assertArrayHasKey()`, `assertContains()`, `assertCount()`
- For PHPUnit, provide custom messages for assertions: `$this->assertTrue($result, 'Expected user to be active')`

## What Not to Mock

- Do not mock the code under test
- Do not mock value objects or data transfer objects
- Mock only at boundaries: HTTP clients (use `symfony/http-client` test tools), databases (use in-memory SQLite), external APIs
- Use interfaces and dependency injection to make code testable
- Prefer fakes over mocks when possible (real implementations with test configuration)
