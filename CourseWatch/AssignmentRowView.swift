import SwiftUI

struct AssignmentRowView: View {
    let assignment: Assignment
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                if let url = assignment.htmlURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                rowContent
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Delete from CourseWatch")
            .padding(.trailing, 12)
            .padding(.top, 10)
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete from CourseWatch", systemImage: "trash")
            }
        }
    }

    private var rowContent: some View {
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
        .padding(.leading, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
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
