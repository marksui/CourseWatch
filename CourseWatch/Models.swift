import Foundation

enum ConnectionMode: String, CaseIterable, Codable, Identifiable {
    case canvasAPI
    case calendarFeed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .canvasAPI:
            return "Canvas API"
        case .calendarFeed:
            return "Calendar Feed"
        }
    }
}

struct Course: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let courseCode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case courseCode = "course_code"
    }
}

struct Assignment: Codable, Identifiable, Hashable {
    let id: Int
    let courseID: Int
    let name: String
    let dueAt: Date?
    let htmlURL: URL?
    let courseName: String

    enum CodingKeys: String, CodingKey {
        case id
        case courseID = "course_id"
        case name
        case dueAt = "due_at"
        case htmlURL = "html_url"
        case courseName
    }
}

struct CanvasAssignmentResponse: Decodable {
    let id: Int
    let courseID: Int?
    let name: String?
    let dueAt: Date?
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case courseID = "course_id"
        case name
        case dueAt = "due_at"
        case htmlURL = "html_url"
    }

    func assignment(courseID fallbackCourseID: Int, courseName: String) -> Assignment {
        Assignment(
            id: id,
            courseID: courseID ?? fallbackCourseID,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled assignment",
            dueAt: dueAt,
            htmlURL: htmlURL,
            courseName: courseName
        )
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
