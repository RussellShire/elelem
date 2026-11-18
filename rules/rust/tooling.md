---
# noinspection YAMLUnresolvedAlias
globs: **/Cargo.toml, **/Cargo.lock, **/rust-toolchain.toml
---

# Rust Tooling

## Project Layout

Use Cargo's standard layout:

```
project/
  Cargo.toml
  Cargo.lock
  src/
    main.rs (for binary) or lib.rs (for library)
  tests/
    integration_test.rs
  benches/
  examples/
```

## Dependency Management

- `Cargo.toml` is the single source of truth for dependencies and metadata
- Never edit `Cargo.lock` by hand; it's managed by Cargo
- Use `cargo add <crate>` to add dependencies
- Separate `[dependencies]` (runtime) from `[dev-dependencies]` (test/build)
- Use `[build-dependencies]` for build script dependencies
- Specify versions with semver: `"1.2.3"` (default, caret-compatible), `"^1.2"` (compatible), `"~1.2.3"` (patch), and `"=1.2.3"` (exact)
- Use workspace for multi-crate projects: `[workspace]` in root `Cargo.toml`

## Formatting and Linting

- Formatter: `cargo fmt` (uses `rustfmt`)
- Linter: `cargo clippy` with project-specific allowed/denied lints
- Run `cargo check` for fast type checking without code generation
- Suppress Clippy warnings with `#[allow(clippy::...)]` only when active project policy permits it and a comment explains why. Functional syntax does not authorise suppressions; fix the underlying issue or seek direction

## Build and Run

- Use `cargo build` for debug builds (fast compilation)
- Use `cargo build --release` for optimised production builds
- Use `cargo run` to build and run in one command
- Use `cargo test` to run all tests (unit, integration, doc tests)
- Use `cargo doc --open` to generate and view documentation
- Specify the toolchain version with `rust-toolchain.toml` for reproducible builds
- Use feature flags for conditional compilation: `--features feature1,feature2`
