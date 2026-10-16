# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities **privately**. Once this project is
hosted, use the hosting platform's private vulnerability reporting (for GitHub:
*Security → Report a vulnerability*). Do not open a public issue for security
problems. A dedicated security contact has not been published yet; the
maintainers will add one here when it exists.

Include: affected build/version, platform, steps to reproduce, impact, and any
proof-of-concept. Please avoid accessing other players' data or degrading
services while testing.

## Supported versions

Pre-release (0.x): only the latest commit on `main` receives fixes.

## Scope

In scope: the game client, dedicated server and lobby service code in this
repository, and the build/release workflows. Out of scope: third-party
platforms, social engineering, denial-of-service volume testing.

## Design notes

The threat model and current mitigations are documented in
[docs/security.md](docs/security.md). Offline saves and the offline coin wallet
are local and tamperable by design; that is not a vulnerability.
