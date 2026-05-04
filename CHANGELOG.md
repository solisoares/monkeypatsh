# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.1] - 2026-05-03

### Fixed

- **Ampersand handling when patching** — correctly parse `&` while patching
- **Completion re-sourcing** — completion functions already loaded in the session are no longer re-sourced on each `mon` call, preventing duplicate registrations and recursive calls
- **Unalias/unhash cleanup** — fix stale aliases/binaries after change of registration type
- **`sed -i` on macOS** — the empty-string argument required by BSD `sed` is now passed as a separate array element, fixing `unregister` and `uninstall` on macOS
- **Patch with spaces** — `mon patch` now rejects subcommand names that contain spaces and prints a helpful suggestion

## [v1.0.0] - 2026-05-01

### Added

- First version of Monkeypatsh

[v1.0.1]: https://github.com/solisoares/monkeypatsh/compare/v1.0.0...v1.0.1
[v1.0.0]: https://github.com/solisoares/monkeypatsh/releases/tag/v1.0.0
