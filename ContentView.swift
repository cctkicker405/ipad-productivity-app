import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }

            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
        }
        .accentColor(.purple)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore

    private var taskCount: Int {
        store.tasks.count
    }

    private var completedCount: Int {
        store.tasks.filter { $0.isDone }.count
    }

    private var pendingCount: Int {
        store.tasks.filter { !$0.isDone }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Good morning")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("Your focus dashboard")
                        .font(.largeTitle.bold())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Tasks", value: "\(taskCount)", color: .blue)
                        StatCard(title: "Done", value: "\(completedCount)", color: .green)
                        StatCard(title: "Open", value: "\(pendingCount)", color: .orange)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Today’s focus")
                                .font(.title2.bold())
                            Spacer()
                            Text("\(store.todayTasks().count) items")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if store.todayTasks().isEmpty {
                            Text("No tasks scheduled today.")
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            ForEach(store.todayTasks()) { task in
                                TaskListRow(task: task, showProjectName: true)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upcoming")
                            .font(.title2.bold())

                        ForEach(Array(store.upcomingTasks().prefix(3)), id: \ .id) { task in
                            UpcomingTaskRow(task: task)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ProjectsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var projectName = ""
    @State private var selectedColor: AppColor = .blue
    @State private var selectedIcon = "folder.fill"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("New project name", text: $projectName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        store.addProject(name: projectName, icon: selectedIcon, color: selectedColor)
                        projectName = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Project color")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(AppColor.allCases, id: \ .self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle().stroke(selectedColor == color ? .primary : .clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                List {
                    ForEach(store.projects) { project in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(project.color.color)
                                    .frame(width: 42, height: 42)
                                Image(systemName: project.icon)
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading) {
                                Text(project.name)
                                    .font(.headline)
                                Text("\(store.tasksForProject(project.id).count) tasks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Projects")
        }
    }
}

struct TasksView: View {
    @EnvironmentObject private var store: AppStore
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedProjectID: UUID? = nil
    @State private var selectedPriority: TaskPriority = .medium
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Task title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField("Notes", text: $notes)
                        .textFieldStyle(.roundedBorder)

                    Picker("Project", selection: $selectedProjectID) {
                        Text("General").tag(UUID?.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Picker("Priority", selection: $selectedPriority) {
                            ForEach(TaskPriority.allCases, id: \ .self) { priority in
                                Text(priority.label).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)

                    Button("Add task") {
                        store.addTask(title: title, notes: notes, projectId: selectedProjectID, dueDate: dueDate, priority: selectedPriority)
                        title = ""
                        notes = ""
                        selectedPriority = .medium
                        dueDate = Date()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()

                List {
                    ForEach(store.tasks) { task in
                        TaskListRow(task: task, showProjectName: true)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Tasks")
        }
    }
}

struct TaskListRow: View {
    @EnvironmentObject private var store: AppStore
    let task: TaskItem
    let showProjectName: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                store.toggleTask(task)
            } label: {
                Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(task.isDone ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isDone)

                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        Label(dateLabel(from: dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if showProjectName {
                        Text(store.projectName(for: task.projectId))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(task.priority.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.priority.color.opacity(0.15))
                    .foregroundStyle(task.priority.color)
                    .clipShape(Capsule())

                Button {
                    store.deleteTask(task.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func dateLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct UpcomingTaskRow: View {
    @EnvironmentObject private var store: AppStore
    let task: TaskItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(task.priority.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                Text(dateString(from: task.dueDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.projectName(for: task.projectId))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dateString(from date: Date?) -> String {
        guard let date else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct NotesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var title = ""
    @State private var content = ""
    @State private var selectedProjectID: UUID? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Note title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Picker("Project", selection: $selectedProjectID) {
                        Text("General").tag(UUID?.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Save note") {
                        store.addNote(title: title, content: content, projectId: selectedProjectID)
                        title = ""
                        content = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()

                List {
                    ForEach(store.notes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(note.title)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    store.deleteNote(note.id)
                                } label: {
                                    Image(systemImage: "trash")
                                        .foregroundStyle(.red)
                                }
                            }

                            Text(note.content)
                                .foregroundStyle(.secondary)

                            if let projectId = note.projectId {
                                Text(store.projectName(for: projectId))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Notes")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
