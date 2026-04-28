import SwiftUI

struct AssignmentRowView: View {
    let assignment: Assignment

    var body: some View {
        Button {
            if let url = assignment.htmlURL {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(urgencyColor)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 5) {
                    Text(assignment.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(dueDateText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(urgencyText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(urgencyColor)
                    }
                }

                Spacer(minLength: 8)

                if assignment.htmlURL != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .disabled(assignment.htmlURL == nil)
    }

    private var iconName: String {
        assignment.dueAt == nil ? "calendar" : "clock"
    }

    private var dueDateText: String {
        guard let dueAt = assignment.dueAt else {
            return "No due date"
        }

        return dueAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var urgencyText: String {
        guard let dueAt = assignment.dueAt else {
            return "No due date"
        }

        let calendar = Calendar.current
        let now = Date()

        if dueAt < now {
            return "Overdue"
        }

        if calendar.isDateInToday(dueAt) {
            return "Due today"
        }

        if calendar.isDateInTomorrow(dueAt) {
            return "Due tomorrow"
        }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfDueDate = calendar.startOfDay(for: dueAt)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0
        return "Due in \(days) days"
    }

    private var urgencyColor: Color {
        guard let dueAt = assignment.dueAt else {
            return .secondary
        }

        let calendar = Calendar.current
        let now = Date()

        if dueAt < now {
            return .red
        }

        if calendar.isDateInToday(dueAt) {
            return .orange
        }

        if calendar.isDateInTomorrow(dueAt) {
            return .yellow
        }

        return .green
    }
}

