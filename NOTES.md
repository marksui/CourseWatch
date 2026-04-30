# CourseWatch Notes

These notes are for the maintainer/developer side of CourseWatch. The public README is written for users.

## Version

Current version: `v2.1.0`

## Scope

CourseWatch is a stable MVP for a local-first macOS menu bar coursework tracker.

- Native SwiftUI app
- `MenuBarExtra` with a window-style popover
- No backend requirement
- No AI features
- macOS 13+
- No third-party libraries

## Website

The static product website lives in `docs/`.

- `docs/index.html`
- `docs/styles.css`

For GitHub Pages, publish the `docs/` folder from the `main` branch.

## Current Features

- Canvas API token mode
- Canvas Calendar Feed / `.ics` fallback mode
- Automatic Calendar Feed URL extraction from pasted text
- External deadlines stored locally
- Assignment cache for offline fallback
- Done checkmarks stored locally
- Hidden Canvas/Feed assignment IDs stored locally
- System notifications 24 hours and 3 hours before due dates
- Keychain storage for Canvas token and Calendar Feed URL
- Base URL and local UI state in `UserDefaults`

## Connection Strategy

CourseWatch v2.1 supports multiple paths because Canvas access depends on school policy:

1. Canvas API token mode: best detail and most reliable when a user or administrator can provide an API token.
2. Canvas OAuth mode: future option only if an institution approves a developer key or OAuth integration.
3. Canvas Calendar Feed / `.ics` mode: fallback when personal tokens or OAuth are blocked.
4. External deadlines: local manual fallback when Canvas cannot expose enough data.
5. Manual import mode: possible future fallback for `.ics` files or `.csv` imports.

CourseWatch should not scrape passwords, bypass school controls, or automate hidden browser login. If Canvas API and OAuth are unavailable, use Calendar Feed or local external deadlines.

## File Structure

```text
CourseWatch.xcodeproj/
CourseWatch/
  CourseWatchApp.swift
  ContentView.swift
  AssignmentRowView.swift
  SettingsView.swift
  EmptyStateView.swift
  Models.swift
  CourseWatchViewModel.swift
  CanvasAPIClient.swift
  ICSCalendarClient.swift
  KeychainManager.swift
  NotificationManager.swift
  Assets.xcassets/
```

## Architecture

`CourseWatchApp` creates the menu bar scene using `MenuBarExtra`.

`ContentView` owns the top-level popover UI state. It switches between the main list, settings, and external deadline editor.

`CourseWatchViewModel` coordinates configuration, assignment fetching, cache reads/writes, local external deadlines, hidden assignment IDs, completed assignment IDs, errors, and notification rescheduling.

`CanvasAPIClient` handles Canvas REST calls. It fetches active courses, then upcoming assignments per course, follows `rel="next"` pagination links, decodes optional Canvas fields safely, and returns assignments sorted by due date.

`ICSCalendarClient` handles the Calendar Feed fallback. It extracts `.ics` or `webcal://` links from pasted text, downloads the feed, parses `VEVENT` entries, and maps them into `Assignment` values.

`KeychainManager` stores the Canvas personal access token as a generic password using service name `CourseWatch.CanvasToken`. It also stores the Calendar Feed URL.

`NotificationManager` requests notification permission and schedules 24-hour and 3-hour reminders. It skips past reminder times and removes old CourseWatch notification requests before rescheduling.

## Canvas API

CourseWatch uses:

- `GET /api/v1/courses?enrollment_state=active&per_page=100`
- `GET /api/v1/courses/{course_id}/assignments?bucket=upcoming&per_page=100`

Headers:

```http
Authorization: Bearer <token>
```

Error cases to preserve:

- Missing configuration
- Invalid URL
- Auth failed for 401 or 403
- Network failure with cache fallback
- JSON decoding error
- Calendar Feed invalid URL or unreadable calendar data

## Local Storage

- Canvas base URL: `UserDefaults`
- Connection mode: `UserDefaults`
- Hidden assignment IDs: `UserDefaults`
- Completed assignment IDs: `UserDefaults`
- Canvas token: Keychain
- Calendar Feed URL: Keychain
- Assignment cache: Application Support JSON
- External deadlines: Application Support JSON

## Run in Xcode

1. Open `CourseWatch.xcodeproj` in Xcode 15 or newer.
2. Select the `CourseWatch` scheme.
3. In Signing & Capabilities, choose a development team if Xcode asks.
4. Build and run on macOS 13 or newer.
5. Click the CourseWatch menu bar icon.

## Local Verification

The local machine may only have Command Line Tools rather than full Xcode. In that case, use:

```bash
swiftc -typecheck -target arm64-apple-macos13.0 CourseWatch/*.swift
```

## User Download Build

The current downloadable app release is:

```text
https://github.com/marksui/CourseWatch/releases/tag/v2.1.0
```

This repository currently builds the local DMG with Command Line Tools using `swiftc`, a hand-written app bundle `Info.plist`, generated `CourseWatch.icns`, and ad-hoc `codesign --sign -`. A full Xcode archive and notarized release should replace this before wider distribution.

## Testing Checklist

- Launches as a menu bar app without a Dock window
- Shows empty state when no deadlines exist
- External deadlines can be added with the plus button
- External deadlines persist after relaunch
- External deadlines can be marked done and deleted
- Settings close button exits Settings without getting stuck
- Canvas base URL saves to `UserDefaults`
- Canvas token saves, reads, and deletes through Keychain
- Calendar Feed URL saves, reads, and deletes through Keychain
- Test succeeds with valid Canvas API settings
- Test succeeds with a valid Calendar Feed URL
- Invalid URL shows an error
- Invalid token shows auth failure for 401 or 403
- Network failure keeps cached assignments visible when available
- Upcoming assignments are sorted by due date
- Assignments without due dates appear after dated assignments
- Clicking an assignment with `html_url` opens the browser
- Refresh fetches courses and assignments again
- Notifications are requested and scheduled only for future 24-hour and 3-hour reminder times
- Completed assignments do not schedule notifications
- Restore Hidden Items brings hidden Canvas/Feed assignments back from cache after refresh
- Reset Done Checkmarks clears completed state
