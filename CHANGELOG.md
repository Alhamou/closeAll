# Changelog

All notable changes to closeAll are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-07

### Added

- A "Background apps" section lists menu-bar apps you installed in `/Applications`
  or `~/Applications`, such as CopyClip or a VPN client. They are unchecked by default.
  Check one to close it too, and closeAll remembers that choice. Apple's own agents,
  helpers packed inside other apps (such as Slack Helper), updaters kept in Library
  folders, and UI-less processes stay hidden and are never closed.

### Fixed

- Force Quit no longer leaves some checked apps running. closeAll now waits for each
  app to exit, sends SIGKILL to any app that survived or refused, and closes a copy
  that a helper relaunched right away. It gives up after three passes.
- An app that refuses to close, or hides its Dock icon while closing, is named in the
  red error line instead of being dropped without a word. closeAll does not keep
  retrying an app that refused.
- The red error line names only apps that are still running, and clears itself once
  they exit. Apps that had already quit on their own are not counted as failures.
- The button shows "Closing…", and the checkboxes are locked until the run has
  finished, so a late change cannot be ignored.
- A process id that another app takes over during the run is never targeted.
- Another copy of closeAll is never a target, even when closeAll runs from `swift run`.
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
