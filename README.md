# CourseWatch

Version: `v2.1.0`

CourseWatch is a small macOS menu bar app that helps you keep track of coursework deadlines. It can connect to Canvas, read upcoming assignments, show them in one quick menu, and remind you before things are due.

CourseWatch is local-first. Your settings and saved deadlines stay on your Mac. There is no backend server and no AI feature.

## What It Does

- Shows upcoming coursework from the macOS menu bar
- Connects to Canvas with a personal access token when your school allows it
- Supports Canvas Calendar Feed links when access tokens are blocked
- Lets you add external deadlines manually
- Sends macOS notifications 24 hours and 3 hours before due dates
- Lets you mark deadlines done with a checkmark
- Lets you delete local external deadlines or hide Canvas items from the list
- Opens assignment links in your default browser
- Keeps cached deadlines visible when you are offline

## Getting Started

1. Open CourseWatch from the macOS menu bar.
2. Click Settings.
3. Paste your Canvas link, for example `https://canvas.ucsd.edu`.
4. Choose one connection method:
   - Canvas API token, if your school lets you create one.
   - Calendar Feed, if tokens are blocked.
5. Click Test to check the connection.
6. Click Save.

You can also use CourseWatch without Canvas by clicking the plus button and adding external deadlines manually.

## Canvas Access Token

A Canvas access token is not your Canvas password. It is a separate key created inside Canvas that lets CourseWatch read your courses and assignments.

To create one:

1. Paste your Canvas link in CourseWatch Settings.
2. Click Get Canvas token.
3. In Canvas, go to Account > Settings > Approved Integrations.
4. Click New Access Token.
5. Use `CourseWatch` as the purpose.
6. Copy the token once and paste it into CourseWatch.

Do not paste your Canvas password into CourseWatch.

## If Canvas Blocks Tokens

Some schools do not let students create their own Canvas access tokens. If Canvas shows a message saying your administrators have limited access token creation, CourseWatch cannot bypass that school setting.

In that case, you can:

- Click Go to Calendar Feed in Settings and use a Canvas Calendar Feed link.
- Click Copy Email to Admin and send the copied request to your Canvas administrator or school IT team.
- Add important deadlines manually with the plus button.

## Calendar Feed Mode

Calendar Feed mode is the best fallback when Canvas API tokens are blocked.

To use it:

1. Open Canvas in your browser.
2. Go to Calendar.
3. Click Calendar Feed.
4. Copy the feed link or the whole popup text.
5. In CourseWatch Settings, choose Calendar Feed.
6. Click Auto Extract.
7. Click Test, then Save.

Calendar Feed mode can show due dates and schedule reminders, but it may not include full course names, submission status, or every Canvas To Do item.

## External Deadlines

External deadlines are local deadlines you add yourself. Use them for exams, readings, club tasks, office hours, project milestones, or anything Canvas does not show.

Click the plus button in CourseWatch, enter a title, optional course/source, due date, and optional link, then Save.

## Privacy and Security

- CourseWatch is open source and provided as-is.
- CourseWatch does not ask for your Canvas password.
- Canvas tokens are stored in the macOS Keychain.
- Calendar Feed links and external deadlines are stored locally on your Mac.
- You are responsible for protecting your passwords, tokens, device, and private information.
- The maintainer is not responsible for password leaks, token leaks, personal information exposure, data loss, account issues, modified builds, compromised devices, user error, or misuse of the app.

## Requirements

- macOS 13 or newer
- Canvas access token or Calendar Feed link, unless you only use manual external deadlines

## Download

The current macOS app ZIP is available at [docs/downloads/CourseWatch-v2.1.0-macOS.zip](docs/downloads/CourseWatch-v2.1.0-macOS.zip).

This build is ad-hoc signed. If macOS shows a warning when opening it, right-click CourseWatch and choose Open.

## Notes for Maintainers

Developer notes, architecture details, Canvas endpoints, setup steps, and the testing checklist are in [NOTES.md](NOTES.md).
