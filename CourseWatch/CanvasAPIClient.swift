import Foundation

enum CanvasAPIError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidResponse
    case authenticationFailed
    case networkFailure(String)
    case decodingFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid Canvas URL."
        case .invalidResponse:
            return "Canvas returned an invalid response."
        case .authenticationFailed:
            return "Canvas authentication failed. Check your access token."
        case .networkFailure(let message):
            return "Network error: \(message)"
        case .decodingFailure(let message):
            return "Could not read Canvas response: \(message)"
        }
    }
}

final class CanvasAPIClient {
    private let baseURL: URL
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURLString: String, token: String, session: URLSession = .shared) throws {
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = baseURL.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              baseURL.host != nil else {
            throw CanvasAPIError.invalidBaseURL
        }

        self.baseURL = baseURL
        self.token = token
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.canvasWithFractionalSeconds.date(from: value) ??
                ISO8601DateFormatter.canvas.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        self.decoder = decoder
    }

    func fetchUpcomingAssignments() async throws -> [Assignment] {
        let courses: [Course] = try await fetchPaginated(
            path: "/api/v1/courses",
            queryItems: [
                URLQueryItem(name: "enrollment_state", value: "active"),
                URLQueryItem(name: "per_page", value: "100")
            ]
        )

        var assignments: [Assignment] = []

        for course in courses {
            let responses: [CanvasAssignmentResponse] = try await fetchPaginated(
                path: "/api/v1/courses/\(course.id)/assignments",
                queryItems: [
                    URLQueryItem(name: "bucket", value: "upcoming"),
                    URLQueryItem(name: "per_page", value: "100")
                ]
            )

            let courseName = course.name.nilIfEmpty ?? course.courseCode ?? "Course \(course.id)"
            assignments.append(contentsOf: responses.map { $0.assignment(courseID: course.id, courseName: courseName) })
        }

        return assignments.sortedByDueDate()
    }

    func testConnection() async throws {
        let _: [Course] = try await fetchPaginated(
            path: "/api/v1/courses",
            queryItems: [
                URLQueryItem(name: "enrollment_state", value: "active"),
                URLQueryItem(name: "per_page", value: "1")
            ]
        )
    }

    private func fetchPaginated<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> [T] {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw CanvasAPIError.invalidBaseURL
        }

        components.queryItems = queryItems

        guard let firstURL = components.url else {
            throw CanvasAPIError.invalidBaseURL
        }

        var nextURL: URL? = firstURL
        var values: [T] = []

        while let url = nextURL {
            let (data, response) = try await performRequest(url: url)

            do {
                values.append(contentsOf: try decoder.decode([T].self, from: data))
            } catch {
                throw CanvasAPIError.decodingFailure(error.localizedDescription)
            }

            nextURL = nextPageURL(from: response)
        }

        return values
    }

    private func performRequest(url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CanvasAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200..<300:
                return (data, httpResponse)
            case 401, 403:
                throw CanvasAPIError.authenticationFailed
            default:
                throw CanvasAPIError.networkFailure("Canvas returned HTTP \(httpResponse.statusCode).")
            }
        } catch let error as CanvasAPIError {
            throw error
        } catch {
            throw CanvasAPIError.networkFailure(error.localizedDescription)
        }
    }

    private func nextPageURL(from response: HTTPURLResponse) -> URL? {
        guard let linkHeader = response.value(forHTTPHeaderField: "Link") else {
            return nil
        }

        return linkHeader
            .split(separator: ",")
            .compactMap { part -> URL? in
                let sections = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                guard sections.contains("rel=\"next\""),
                      let urlSection = sections.first,
                      urlSection.hasPrefix("<"),
                      urlSection.hasSuffix(">") else {
                    return nil
                }

                let urlString = String(urlSection.dropFirst().dropLast())
                return URL(string: urlString)
            }
            .first
    }
}

private extension ISO8601DateFormatter {
    static let canvas: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let canvasWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension Array where Element == Assignment {
    func sortedByDueDate() -> [Assignment] {
        sorted { lhs, rhs in
            switch (lhs.dueAt, rhs.dueAt) {
            case let (left?, right?):
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }
}
