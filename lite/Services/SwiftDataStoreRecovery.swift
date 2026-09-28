import Foundation
import SQLite3

/// Repairs the one known interrupted lightweight migration shipped with Lite 2.2.
/// The failed migration can leave its relationship column behind while the store
/// metadata still describes the previous schema. Retrying then attempts to add the
/// same column and fails with SQLite's "duplicate column name: Z2APPS" error.
enum SwiftDataStoreRecovery {
    private static let appTable = "ZLITEAPP"
    private static let orphanedColumn = "Z2APPS"
    private static let orphanedIndex = "ZLITEAPP_Z2APPS_INDEX"
    private static let collectionTable = "ZLITEAPPCOLLECTION"

    /// Returns the backup directory when a repair was performed, otherwise `nil`.
    static func repairInterruptedCollectionMigration(at storeURL: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            defer { sqlite3_close(database) }
            let message = database == nil
                ? "Unable to open the store"
                : String(cString: sqlite3_errmsg(database))
            throw RecoveryError.sqlite(message: message)
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 5_000)

        guard try hasColumn(orphanedColumn, in: appTable, database: database),
              try !hasTable(collectionTable, database: database) else {
            return nil
        }

        let backupDirectory = try backUpStore(at: storeURL)
        do {
            try execute("BEGIN IMMEDIATE", database: database)
            try execute("DROP INDEX IF EXISTS \(orphanedIndex)", database: database)
            try execute("ALTER TABLE \(appTable) DROP COLUMN \(orphanedColumn)", database: database)
            try execute("COMMIT", database: database)
            return backupDirectory
        } catch {
            _ = try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    private static func backUpStore(at storeURL: URL) throws -> URL {
        let directory = storeURL.deletingLastPathComponent()
            .appendingPathComponent("LiteMigrationBackups", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(
                at: source,
                to: directory.appendingPathComponent(source.lastPathComponent)
            )
        }
        return directory
    }

    private static func hasTable(_ name: String, database: OpaquePointer) throws -> Bool {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let sql = "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = '\(name)' LIMIT 1"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw RecoveryError.sqlite(message: sqliteMessage(database))
        }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static func hasColumn(
        _ column: String,
        in table: String,
        database: OpaquePointer
    ) throws -> Bool {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK else {
            throw RecoveryError.sqlite(message: sqliteMessage(database))
        }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let value = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: value) == column { return true }
        }
        return false
    }

    @discardableResult
    private static func execute(_ sql: String, database: OpaquePointer) throws -> Int32 {
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw RecoveryError.sqlite(message: sqliteMessage(database))
        }
        return result
    }

    private static func sqliteMessage(_ database: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(database))
    }

    private enum RecoveryError: LocalizedError {
        case sqlite(message: String)

        var errorDescription: String? {
            switch self {
            case .sqlite(let message): "SQLite recovery failed: \(message)"
            }
        }
    }
}
