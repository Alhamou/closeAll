# Contributing to closeAll

Thanks for looking at closeAll. The useful change is a small one: a bug fix, a clearer quit rule, or a test that locks that rule in.

## Development setup

- macOS 14 or later
- Xcode or the Swift toolchain that comes with it

```bash
git clone git@github.com:Alhamou/closeAll.git
cd closeAll
swift test
make check
```

`make check` must pass before a pull request. It runs the unit tests and a live dry-run. The dry-run does not quit any app. It fails if Finder, closeAll, or a session process would be force-quit.

```bash
swift run closeAll -- --demo-window
```

That opens the panel in a normal window so you can look at layout without using the menu bar.

## What to change where

Quit decisions live in `Sources/closeAllCore`. That target does not import AppKit, so the tests can run the rules without closing real apps. If you change who gets quit, add or update a test in `Tests/closeAllCoreTests`.

The menu bar, icons, and `NSRunningApplication.forceTerminate()` live in `Sources/closeAll`. Do not call force-quit from a test.

## Pull requests

1. Fork the repository and create a branch.
2. Keep the change focused.
3. Run `make check`.
4. Describe why the change is needed, and how you tested it.
5. Do not commit `.build/`, `build/`, or secrets.

The app version is `CFBundleShortVersionString` in `Resources/Info.plist`. User-visible releases also get a note in `CHANGELOG.md`.

## Reports

Use a [bug report](.github/ISSUE_TEMPLATE/bug_report.md) or a [feature request](.github/ISSUE_TEMPLATE/feature_request.md). Security issues go through [SECURITY.md](SECURITY.md), not a public issue.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
