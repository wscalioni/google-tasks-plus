import Foundation
import GRDB

final class DatabaseManager: Sendable {
    static let shared = DatabaseManager()

    let pool: DatabasePool

    private init() {
        let url = Self.databaseURL
        do {
            pool = try DatabasePool(path: url.path, configuration: Self.makeConfiguration())
            try Self.makeMigrator().migrate(pool)
        } catch {
            fatalError("DatabaseManager: failed to initialize database: \(error)")
        }
    }

    // MARK: - Database Location

    private static var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("GoogleTasksPlus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tasks.sqlite")
    }

    private static func makeConfiguration() -> Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.label = "GoogleTasksPlus"
        return config
    }

    // MARK: - Migrations

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial_schema") { db in
            try db.execute(sql: """
                CREATE TABLE task_lists (
                    id          TEXT PRIMARY KEY NOT NULL,
                    title       TEXT NOT NULL,
                    updated     TEXT,
                    sync_status TEXT NOT NULL DEFAULT 'synced'
                );

                CREATE TABLE tasks (
                    id            TEXT PRIMARY KEY NOT NULL,
                    list_id       TEXT NOT NULL REFERENCES task_lists(id) ON DELETE CASCADE,
                    title         TEXT NOT NULL DEFAULT '',
                    notes         TEXT,
                    status        TEXT NOT NULL DEFAULT 'needsAction',
                    due           TEXT,
                    updated       TEXT,
                    completed     TEXT,
                    parent        TEXT,
                    position      TEXT,
                    sync_status   TEXT NOT NULL DEFAULT 'synced',
                    local_updated TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
                );

                CREATE INDEX idx_tasks_list_id ON tasks(list_id);
                CREATE INDEX idx_tasks_sync_status ON tasks(sync_status);
                CREATE INDEX idx_task_lists_sync_status ON task_lists(sync_status);
                """)
        }

        return migrator
    }

    // MARK: - Task List CRUD

    func upsertTaskList(_ record: TaskListRecord) throws {
        try pool.write { db in
            var mutable = record
            try mutable.save(db, onConflict: .replace)
        }
    }

    func deleteTaskList(id: String) throws {
        try pool.write { db in
            _ = try TaskListRecord.deleteOne(db, id: id)
        }
    }

    func fetchAllTaskLists() throws -> [TaskListRecord] {
        try pool.read { db in
            try TaskListRecord
                .filter(Column("sync_status") != SyncStatus.pendingDelete.rawValue)
                .fetchAll(db)
        }
    }

    func fetchTaskLists(withSyncStatus status: SyncStatus) throws -> [TaskListRecord] {
        try pool.read { db in
            try TaskListRecord
                .filter(Column("sync_status") == status.rawValue)
                .fetchAll(db)
        }
    }

    // MARK: - Task CRUD

    func upsertTask(_ record: TaskRecord) throws {
        try pool.write { db in
            var mutable = record
            try mutable.save(db, onConflict: .replace)
        }
    }

    func deleteTask(id: String) throws {
        try pool.write { db in
            _ = try TaskRecord.deleteOne(db, id: id)
        }
    }

    func fetchAllTasks() throws -> [TaskRecord] {
        try pool.read { db in
            try TaskRecord
                .filter(Column("sync_status") != SyncStatus.pendingDelete.rawValue)
                .fetchAll(db)
        }
    }

    func fetchTasks(withSyncStatus status: SyncStatus) throws -> [TaskRecord] {
        try pool.read { db in
            try TaskRecord
                .filter(Column("sync_status") == status.rawValue)
                .fetchAll(db)
        }
    }

    func markTaskSynced(id: String, newId: String? = nil, apiUpdated: String?) throws {
        try pool.write { db in
            if let newId = newId, newId != id {
                if var record = try TaskRecord.fetchOne(db, id: id) {
                    _ = try TaskRecord.deleteOne(db, id: id)
                    record.id = newId
                    record.syncStatus = .synced
                    if let apiUpdated = apiUpdated {
                        record.updated = apiUpdated
                        record.localUpdated = apiUpdated
                    }
                    try record.insert(db)
                }
            } else {
                if var record = try TaskRecord.fetchOne(db, id: id) {
                    record.syncStatus = .synced
                    if let apiUpdated = apiUpdated {
                        record.updated = apiUpdated
                        record.localUpdated = apiUpdated
                    }
                    try record.update(db)
                }
            }
        }
    }

    func markTaskListSynced(id: String, apiUpdated: String?) throws {
        try pool.write { db in
            if var record = try TaskListRecord.fetchOne(db, id: id) {
                record.syncStatus = .synced
                if let apiUpdated = apiUpdated {
                    record.updated = apiUpdated
                }
                try record.update(db)
            }
        }
    }

    // MARK: - Bulk Import (used during full sync pull)

    func replaceAllData(lists: [TaskListRecord], tasks: [TaskRecord]) throws {
        try pool.write { db in
            let pendingTasks = try TaskRecord
                .filter(Column("sync_status") != SyncStatus.synced.rawValue)
                .fetchAll(db)
            let pendingTaskIds = Set(pendingTasks.map(\.id))

            let pendingLists = try TaskListRecord
                .filter(Column("sync_status") != SyncStatus.synced.rawValue)
                .fetchAll(db)
            let pendingListIds = Set(pendingLists.map(\.id))

            _ = try TaskRecord
                .filter(Column("sync_status") == SyncStatus.synced.rawValue)
                .deleteAll(db)
            _ = try TaskListRecord
                .filter(Column("sync_status") == SyncStatus.synced.rawValue)
                .deleteAll(db)

            for list in lists where !pendingListIds.contains(list.id) {
                var mutable = list
                try mutable.save(db, onConflict: .replace)
            }

            for task in tasks where !pendingTaskIds.contains(task.id) {
                var mutable = task
                try mutable.save(db, onConflict: .replace)
            }
        }
    }

    // MARK: - Observation Builders

    func observeAllTaskLists() -> ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<[TaskListRecord]>>> {
        ValueObservation.tracking { db in
            try TaskListRecord
                .filter(Column("sync_status") != SyncStatus.pendingDelete.rawValue)
                .fetchAll(db)
        }.removeDuplicates()
    }

    func observeAllTasks() -> ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<[TaskRecord]>>> {
        ValueObservation.tracking { db in
            try TaskRecord
                .filter(Column("sync_status") != SyncStatus.pendingDelete.rawValue)
                .fetchAll(db)
        }.removeDuplicates()
    }
}
