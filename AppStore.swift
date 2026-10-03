import Foundation
import SwiftUI

final class AppStore: ObservableObject {
    @Published var projects: [Project] {
        didSet { save() }
    }

    @Published var tasks: [TaskItem] {
        didSet { save() }
    }

    @Published var notes: [NoteItem] {
        didSet { save() }
    }

    init() {
        let seed = AppStore.defaultData()
        self.projects = seed.projects
        self.tasks = seed.tasks
        self.notes = seed.notes

        if let saved = Self.load() {
            self.projects = saved.projects
            self.tasks = saved.tasks
            self.notes = saved.notes
        }
    }

    static func defaultData() -> (projects: [Project], tasks: [TaskItem], notes: [NoteItem]) {
        let projects = [
            Project(name: "Design Sprint", icon: "paintbrush.fill", color: .purple),
            Project(name: "Operations", icon: "briefcase.fill", color: .blue),
            Project(name: "Personal", icon: "person.fill", color: .green)
        ]

        let tasks = [
            TaskItem(title: "Review product roadmap", notes: "Check strategic priorities.", projectId: nil, dueDate: Date().addingTimeInterval(86400), priority: .high, isDone: false),
            TaskItem(title: "Prepare prototype review", notes: "Capture feedback and next steps.", projectId: nil, dueDate: Date().addingTimeInterval(172800), priority: .medium, isDone: false),
            TaskItem(title: "Weekly planning notes", notes: "Summarize the goals for the week.", projectId: nil, dueDate: Date().addingTimeInterval(345600), priority: .low, isDone: true)
        ]

        let notes = [
            NoteItem(title: "Morning focus", content: "Keep the day centered on the top priority and remove distractions.", projectId: nil),
            NoteItem(title: "Sprint idea", content: "Create a mini checklist for faster handoff between teams.", projectId: nil)
        ]

        return (projects, tasks, notes)
    }

    func addProject(name: String, icon: String, color: AppColor) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let project = Project(name: trimmedName, icon: icon, color: color)
        projects.insert(project, at: 0)
    }

    func addTask(title: String, notes: String = "", projectId: UUID? = nil, dueDate: Date? = nil, priority: TaskPriority = .medium) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let task = TaskItem(title: trimmedTitle, notes: notes, projectId: projectId, dueDate: dueDate, priority: priority)
        tasks.insert(task, at: 0)
    }

    func toggleTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDone.toggle()
    }

    func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    func addNote(title: String, content: String, projectId: UUID? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else { return }

        let note = NoteItem(title: trimmedTitle.isEmpty ? "Untitled Note" : trimmedTitle, content: trimmedContent, projectId: projectId)
        notes.insert(note, at: 0)
    }

    func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
    }

    func projectName(for id: UUID?) -> String {
        guard let id else { return "General" }
        return projects.first(where: { $0.id == id })?.name ?? "General"
    }

    func tasksForProject(_ projectId: UUID?) -> [TaskItem] {
        tasks.filter { $0.projectId == projectId }
    }

    func overdueTasks() -> [TaskItem] {
        tasks.filter {
            !$0.isDone && $0.dueDate != nil && $0.dueDate! < Date()
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func todayTasks() -> [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter {
            guard !$0.isDone, let dueDate = $0.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: Date())
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func upcomingTasks() -> [TaskItem] {
        tasks.filter { !$0.isDone && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func save() {
        let snapshot = (projects, tasks, notes)
        let encoder = JSONEncoder()

        if let projectData = try? encoder.encode(snapshot.0),
           let taskData = try? encoder.encode(snapshot.1),
           let noteData = try? encoder.encode(snapshot.2) {
            UserDefaults.standard.set(projectData, forKey: "productivity.projects")
            UserDefaults.standard.set(taskData, forKey: "productivity.tasks")
            UserDefaults.standard.set(noteData, forKey: "productivity.notes")
        }
    }

    private static func load() -> (projects: [Project], tasks: [TaskItem], notes: [NoteItem])? {
        let defaults = UserDefaults.standard
        guard
            let projectData = defaults.data(forKey: "productivity.projects"),
            let taskData = defaults.data(forKey: "productivity.tasks"),
            let noteData = defaults.data(forKey: "productivity.notes"),
            let projects = try? JSONDecoder().decode([Project].self, from: projectData),
            let tasks = try? JSONDecoder().decode([TaskItem].self, from: taskData),
            let notes = try? JSONDecoder().decode([NoteItem].self, from: noteData)
        else {
            return nil
        }

        return (projects, tasks, notes)
    }
}
