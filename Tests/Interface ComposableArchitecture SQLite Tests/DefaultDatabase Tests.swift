import Dependencies
import GRDB
import Interface_ComposableArchitecture_SQLite
import Testing

@Suite struct `The default database` {
    @Test func `an unset default database reports it and is a blank one in memory`() throws {
        try withKnownIssue {
            @Dependency(\.defaultDatabase) var database
            let tables = try database.read { db in try String.fetchAll(db, sql: "SELECT name FROM sqlite_master") }
            #expect(tables.isEmpty)
        } matching: { issue in
            issue.description.contains("A blank, in-memory database is being used")
        }
    }

    @Test func `a prepared default database is the one every reader gets`() throws {
        let prepared = try DatabaseQueue()
        try prepared.write { db in try db.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)") }
        try withDependencies {
            $0.defaultDatabase = prepared
        } operation: {
            @Dependency(\.defaultDatabase) var database
            let exists = try database.read { db in try db.tableExists("item") }
            #expect(exists)
        }
    }

    @Test func `in a test context the database is a fresh file, with the canonical collation`() throws {
        let database = try defaultDatabase()
        #expect(database is DatabasePool)
        let ordered = try database.read { db in
            try String.fetchAll(db, sql: "SELECT value FROM (SELECT 'e\u{301}' AS value UNION ALL SELECT 'é') ORDER BY value COLLATE canonical")
        }
        #expect(ordered.count == 2)
    }
}
