import Foundation

enum ICSCalendarError: LocalizedError {
    case invalidFeedURL
    case noFeedURLFound
    case invalidResponse
    case networkFailure(String)
    case invalidCalendarData

    var errorDescription: String? {
        switch self {
        case .invalidFeedURL:
            return "Invalid Calendar Feed URL."
        case .noFeedURLFound:
            return "Could not find an .ics or webcal link in that text."
        case .invalidResponse:
            return "Calendar Feed returned an invalid response."
        case .networkFailure(let message):
            return "Calendar Feed error: \(message)"
        case .invalidCalendarData:
            return "Could not read Calendar Feed data."
        }
    }
}

final class ICSCalendarClient {
    private let feedURL: URL
    private let session: URLSession

    init(feedURLString: String, session: URLSession = .shared) throws {
        guard let url = Self.normalizedFeedURL(from: feedURLString) else {
            throw ICSCalendarError.invalidFeedURL
        }

        self.feedURL = url
        self.session = session
    }

    func fetchAssignments() async throws -> [Assignment] {
        var request = URLRequest(url: feedURL)
        request.setValue("text/calendar,*/*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ICSCalendarError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ICSCalendarError.networkFailure("Feed returned HTTP \(httpResponse.statusCode).")
            }

            guard let calendarText = String(data: data, encoding: .utf8) ??
                    String(data: data, encoding: .isoLatin1) else {
                throw ICSCalendarError.invalidCalendarData
            }

            return Self.parseAssignments(from: calendarText).sortedByDueDate()
        } catch let error as ICSCalendarError {
            throw error
        } catch {
            throw ICSCalendarError.networkFailure(error.localizedDescription)
        }
    }

    static func extractFeedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directURL = normalizedFeedURL(from: trimmed), looksLikeFeedURL(directURL) {
            return directURL
        }

        let pattern = #"(webcal|https?)://[^\s<>"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let matches = regex.matches(in: trimmed, options: [], range: range)

        return matches
            .compactMap { match -> URL? in
                guard let range = Range(match.range, in: trimmed) else {
                    return nil
                }

                let candidate = String(trimmed[range])
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;)]}"))
                return normalizedFeedURL(from: candidate)
            }
            .first(where: looksLikeFeedURL)
    }

    static func normalizedFeedURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        let valueWithScheme: String
        if trimmedValue.lowercased().hasPrefix("webcal://") {
            valueWithScheme = "https://" + trimmedValue.dropFirst("webcal://".count)
        } else if trimmedValue.contains("://") {
            valueWithScheme = trimmedValue
        } else {
            valueWithScheme = "https://\(trimmedValue)"
        }

        guard var components = URLComponents(string: valueWithScheme),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return nil
        }

        components.scheme = scheme
        return components.url
    }

    static func parseAssignments(from calendarText: String) -> [Assignment] {
        let lines = unfoldedLines(from: calendarText)
        var events: [[String: String]] = []
        var currentEvent: [String: String]?

        for line in lines {
            if line == "BEGIN:VEVENT" {
                currentEvent = [:]
                continue
            }

            if line == "END:VEVENT" {
                if let currentEvent {
                    events.append(currentEvent)
                }
                currentEvent = nil
                continue
            }

            guard currentEvent != nil else {
                continue
            }

            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                continue
            }

            let key = parts[0].split(separator: ";", maxSplits: 1)[0].uppercased()
            let value = String(parts[1])
            currentEvent?[key] = value
        }

        return events.compactMap(assignment(from:))
    }

    private static func assignment(from event: [String: String]) -> Assignment? {
        let uid = event["UID"] ?? event["SUMMARY"] ?? UUID().uuidString
        let summary = unescape(event["SUMMARY"] ?? "Untitled Canvas event")
        let description = unescape(event["DESCRIPTION"] ?? "")
        let location = unescape(event["LOCATION"] ?? "")
        let dueAt = parseDate(event["DUE"]) ??
            parseDate(event["DTSTART"]) ??
            parseDate(event["DTEND"])
        let url = URL(string: unescape(event["URL"] ?? "")) ?? firstURL(in: description)
        let courseName = courseName(from: summary, description: description, location: location)

        return Assignment(
            id: stableID(from: uid),
            courseID: stableID(from: courseName),
            name: assignmentName(from: summary),
            dueAt: dueAt,
            htmlURL: url,
            courseName: courseName
        )
    }

    private static func unfoldedLines(from text: String) -> [String] {
        var lines: [String] = []

        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                guard !lines.isEmpty else {
                    lines.append(line.trimmingCharacters(in: .whitespaces))
                    continue
                }
                lines[lines.count - 1] += line.dropFirst()
            } else {
                lines.append(line)
            }
        }

        return lines
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            ("yyyyMMdd'T'HHmmss'Z'", TimeZone(secondsFromGMT: 0)),
            ("yyyyMMdd'T'HHmmss", TimeZone.current),
            ("yyyyMMdd", TimeZone.current)
        ]

        for (format, timeZone) in formats {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = format

            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return ISO8601DateFormatter().date(from: trimmed)
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstURL(in text: String) -> URL? {
        let pattern = #"https?://[^\s<>"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let urlRange = Range(match.range, in: text) else {
            return nil
        }

        let urlString = String(text[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;)]}"))
        return URL(string: urlString)
    }

    private static func courseName(from summary: String, description: String, location: String) -> String {
        let candidates = [location, description]
        for candidate in candidates {
            let lines = candidate.components(separatedBy: .newlines)
            if let courseLine = lines.first(where: { $0.localizedCaseInsensitiveContains("course") }) {
                return courseLine
                    .replacingOccurrences(of: "Course:", with: "", options: [.caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty ?? "Canvas Calendar"
            }
        }

        if summary.contains(":") {
            return summary.components(separatedBy: ":")[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? "Canvas Calendar"
        }

        return "Canvas Calendar"
    }

    private static func assignmentName(from summary: String) -> String {
        guard summary.contains(":") else {
            return summary
        }

        return summary
            .components(separatedBy: ":")
            .dropFirst()
            .joined(separator: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? summary
    }

    private static func stableID(from value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return Int(hash & UInt64(Int.max))
    }

    private static func looksLikeFeedURL(_ url: URL) -> Bool {
        let value = url.absoluteString.lowercased()
        return value.contains(".ics") ||
            value.contains("ical") ||
            value.contains("calendar_feed") ||
            value.contains("/feeds/calendars/")
    }
}
