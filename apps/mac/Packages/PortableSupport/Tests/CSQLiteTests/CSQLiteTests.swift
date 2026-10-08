import CSQLite
import Foundation
import Testing

@Suite struct CSQLiteTests {
    @Test func opensInMemoryDatabaseWithFTS5() throws {
        var db: OpaquePointer?
        #expect(sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }

        #expect(sqlite3_exec(db, "CREATE VIRTUAL TABLE t USING fts5(name, content)", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(db, "INSERT INTO t (name, content) VALUES ('Amazing Grace', 'how sweet the sound')", nil, nil, nil) == SQLITE_OK)

        var stmt: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, "SELECT name FROM t WHERE t MATCH 'sweet'", -1, &stmt, nil) == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        #expect(sqlite3_step(stmt) == SQLITE_ROW)
        let name = sqlite3_column_text(stmt, 0).map { String(cString: $0) }
        #expect(name == "Amazing Grace")
    }

    @Test func reportsVersion() {
        let version = String(cString: sqlite3_libversion())
        #expect(version.hasPrefix("3."))
    }
}
