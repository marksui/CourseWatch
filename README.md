# CourseWatch

Version: `v2.0.0`

CourseWatch is a local-first macOS menu bar app for tracking Canvas LMS coursework deadlines. It fetches active courses and upcoming assignments, keeps a small offline cache, and schedules system notifications before due dates.

## Features

- Native SwiftUI menu bar app using `MenuBarExtra`
- Canvas settings for base URL and personal access token
- Secure token storage in Keychain
- Canvas API client with async `URLSession`, auth handling, decoding errors, network errors, and basic Link-header pagination
- Upcoming assignment list sorted by due date
- Assignment urgency labels: overdue, due today, due tomorrow, due in X days, or no due date
- Clickable assignment rows that open Canvas in the default browser
- Local assignment cache for offline fallback
- System notifications 24 hours and 3 hours before due dates

## v2.0 Connection Strategy

CourseWatch v2.0 is planned around multiple connection modes so the app can still be useful when a school locks down Canvas API access:

1. Canvas API token mode: best detail and most reliable when the user or administrator can provide a Canvas API access token.
2. Canvas OAuth mode: future login flow if the Canvas institution approves a developer key or OAuth integration.
3. Canvas Calendar Feed / `.ics` mode: fallback mode for schools that block both personal tokens and OAuth. This can still show due dates from a Canvas calendar feed, but may have less course/assignment detail than the API.
4. Manual import mode: final fallback for `.ics`, `.csv`, or manually entered deadlines when Canvas integrations are unavailable.

If OAuth/login flow also does not work, CourseWatch should not scrape passwords, bypass school controls, or automate hidden browser login. The correct fallback is Calendar Feed / `.ics` or manual import.

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
  KeychainManager.swift
  NotificationManager.swift
  Assets.xcassets/
```

## Architecture

`CourseWatchApp` creates a `MenuBarExtra` with a window-style popover. `ContentView` switches between setup, empty, loading, error, and assignment-list states.

`CourseWatchViewModel` is the main app coordinator. It loads configuration, reads and writes cached assignments, refreshes Canvas data, exposes UI state, and asks `NotificationManager` to reschedule reminders after successful refreshes.

`CanvasAPIClient` handles Canvas REST calls. It fetches active courses, then upcoming assignments per course, follows `rel="next"` pagination links, decodes optional Canvas fields safely, and returns assignments sorted by due date.

`KeychainManager` stores the Canvas personal access token as a generic password using service name `CourseWatch.CanvasToken`. The Canvas base URL is stored in `UserDefaults`.

## Run in Xcode

1. Open `CourseWatch.xcodeproj` in Xcode 15 or newer.
2. Select the `CourseWatch` scheme.
3. In Signing & Capabilities, choose your development team if Xcode asks.
4. Build and run on macOS 13 or newer.
5. Click the CourseWatch menu bar icon, open Settings, and enter:
   - Canvas link or base URL, for example `https://canvas.ucsd.edu`
   - Canvas personal access token
6. Use Get Canvas token in Settings if you need to create a token.
7. Click Test Connection, then Save.

## Canvas Token

A Canvas token is a password substitute that lets CourseWatch read your Canvas courses and assignments without storing your Canvas password.

To create one:

1. Paste your Canvas link into CourseWatch Settings, for example `https://canvas.ucsd.edu`.
2. Click Get Canvas token.
3. In Canvas, go to Approved Integrations and click New Access Token.
4. Use `CourseWatch` as the purpose.
5. Generate the token, copy the token value once, and paste it into CourseWatch Settings.

If Canvas says your administrators have limited your ability to generate access tokens, CourseWatch v2.0.0 cannot bypass that setting. Contact your Canvas administrator or school IT team and ask them to generate a Canvas API access token for your account, ask whether OAuth/developer-key access is available, or use a Canvas Calendar Feed / `.ics` fallback if your school exposes one.

CourseWatch uses:

- `GET /api/v1/courses?enrollment_state=active&per_page=100`
- `GET /api/v1/courses/{course_id}/assignments?bucket=upcoming&per_page=100`

The token is sent as:

```http
Authorization: Bearer <token>
```

## Open Source and Security Disclaimer

- CourseWatch is an open-source app provided as-is.
- Do not enter your Canvas password into CourseWatch. Only use a Canvas personal access token created from your Canvas account settings.
- You are responsible for keeping your passwords, tokens, device, and private information secure.
- The maintainer is not responsible or liable for password leaks, token leaks, personal information exposure, data loss, account issues, modified builds, third-party services, compromised devices, user error, or misuse of the app.

## Testing Checklist

- Launches as a menu bar app without a Dock window
- Shows setup state when URL or token is missing
- Saves base URL to `UserDefaults`
- Saves, reads, and deletes token through Keychain
- Test Connection succeeds with valid Canvas settings
- Invalid URL shows an error
- Invalid token shows auth failure for 401 or 403
- Network failure keeps cached assignments visible when available
- Upcoming assignments are sorted by due date
- Assignments without due dates appear after dated assignments
- Clicking an assignment with `html_url` opens the browser
- Refresh fetches courses and assignments again
- Notifications are requested and scheduled only for future 24h and 3h reminder times
