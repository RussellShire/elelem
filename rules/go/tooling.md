---
# noinspection YAMLUnresolvedAlias
globs: **/go.mod, **/go.sum, **/go.work
---

# Go Tooling

## Project Layout

Use the standard Go project layout:

```
project/
  go.mod
  cmd/
    appname/
      main.go
  internal/
    (internal packages)
  pkg/
    (public library code)
  tests/
    (integration tests)
```

## Dependency Management

- `go.mod` is the single source of truth for dependencies
- Use Go modules (default since Go 1.16)
- Run `go mod tidy` after adding or removing dependencies
- Use `go mod vendor` only if you need vendored dependencies
- Pin dependencies with specific versions; `go.mod` tracks both direct and indirect dependencies
- Use workspaces (`go.work`) for multi-module projects in development

## Formatting and Linting

- Formatter: `gofmt` or `goimports` (adds import management)
- Linter: `golangci-lint` with a project-specific configuration
- Run `go vet` to catch common mistakes
- Suppress a lint error only when active project policy permits it and the required `//nolint:rulename // reason` explanation states why. Functional syntax does not authorise suppressions; fix the underlying issue or seek direction

## Build and Run

- Use `go build` for production builds
- Use `go run` for quick development iteration
- Enable module mode explicitly if needed: `GO111MODULE=on`
- Use build tags for conditional compilation: `//go:build linux`
- Set version info at build time with `-ldflags "-X main.Version=..."`
