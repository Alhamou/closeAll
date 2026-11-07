# Changelog

All notable changes to closeAll are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-07

### Fixed

- Force Quit no longer leaves some checked apps running. closeAll now waits for each
  app to exit, sends SIGKILL to any app that survived or refused, and closes a copy
  that a helper relaunched right away. It gives up after three passes.
- The red error line now names the apps that are still running, and no longer counts
  apps that had already quit on their own as failures.
- The button shows "Closing…" and stays disabled until the run has finished.
- A keep choice for an app without a bundle id is dropped when that process exits,
  so a reused process id does not inherit it.

## [1.0.0] - 2026-10-16

### Added

- Menu-bar button that force-quits normal Dock apps on macOS.
- App icons and checkboxes, with a remembered keep-list.
- Finder, closeAll, and session processes are never targets.
- `--dry-run` prints the quit plan and exits without closing apps.
- Unit tests for the quit rules.

[1.1.0]: https://github.com/Alhamou/closeAll/releases/tag/v1.1.0
[1.0.0]: https://github.com/Alhamou/closeAll/releases/tag/v1.0.0
