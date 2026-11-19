---
# noinspection YAMLUnresolvedAlias
globs: **/test_*.py, **/*_test.py, **/tests/**/*.py, **/conftest.py
---

# Python Testing

## Framework

Use `pytest` for new projects or projects without an established applicable framework. Preserve the established applicable framework, including `unittest`, for new code in existing projects. Do not introduce a second runner or migrate frameworks without an approved migration. A framework preference does not authorise dependency installation. When multiple frameworks are established, use project context or ask the user rather than assuming a hierarchy. Framework-specific API instructions and examples below apply only when using the named framework. In an existing project with a different established applicable framework, use its equivalent APIs rather than changing frameworks to follow an example. In established unittest projects, class-level `setUp`/`tearDown` methods, `subTest` and `assertRaises` remain valid.

## File and Function Naming

- Test files: `test_<module>.py` (preferred) or `<module>_test.py` (accepted if the project already uses it)
- For pytest, name test functions with complete descriptive phrases such as `def test_<scenario>():`
- In pytest, fixtures live in `conftest.py` at the closest relevant scope

## Structure

- One assertion concept per test. Multiple `assert` lines are fine if they verify one behaviour
- For pytest, do not use class-based setup or teardown; use fixtures
- In pytest, parameterise with `@pytest.mark.parametrize` rather than copy-pasting tests
- In pytest, prefer the `tmp_path` and `monkeypatch` fixtures over manual temporary files or `unittest.mock.patch`

## Assertions

- In pytest, use plain `assert` statements, which pytest rewrites for good failure messages
- For pytest exceptions, use `with pytest.raises(ValueError, match="..."):`
- For pytest exception tests, use `pytest.raises` instead of catch-and-assert. In unittest tests, use `assertRaises`.

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or data classes
- Mock only at boundaries: network, file system (when `tmp_path` is not enough), clocks, randomness
