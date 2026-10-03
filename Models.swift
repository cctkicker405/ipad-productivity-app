import Foundation
import SwiftUI

enum AppColor: String, Codable, CaseIterable {
    case blue
    case purple
    case green
    case orange
    case red
    case teal

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct Project: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String
    var color: AppColor
    var createdAt: Date = Date()
}

struct TaskItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var projectId: UUID?
    var dueDate: Date?
    var priority: TaskPriority = .medium
    var isDone: Bool = false
    var createdAt: Date = Date()
}

struct NoteItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var projectId: UUID?
    var createdAt: Date = Date()
}
