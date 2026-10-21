public import Dependencies
internal import Foundation
public import GRDB
internal import SQLite

// Ported from pointfreeco/sqlite-data `Sources/SQLiteData/StructuredQueries+GRDB/DefaultDatabase.swift` at
// `6390b5c076764c74713a3fd4ebcc3b61b2220dda`. It lives in this bridge, not in swift-sqlite, because swift-sqlite takes
// no dependencies library (its UPSTREAM.md); it moves there behind a trait once Laurie and TCA26 use the Institute's
// swift-dependencies (coenttb/work#115).

/// Prepares a context-sensitive database writer.
///
///   * In a live app context (e.g. simulator, device), a database pool is provisioned in the app
///     container (unless explicitly overridden with the `path` parameter).
///   * In an Xcode preview context, an in-memory database is provisioned.
///   * In a test context, a database pool is provisioned at a temporary file.
///
/// - Parameters:
///   - path: A path to the database. If `nil`, a path to a file in the application support
///     directory will be used.
///   - configuration: A database configuration.
/// - Returns: A context-sensitive database writer.
public func defaultDatabase(
    path: String? = nil,
    configuration: Configuration = Configuration()
) throws -> any DatabaseWriter {
    var configuration = configuration
    configuration.prepareDatabase { db in
        db.add(collation: .canonical)
    }
    let database: any DatabaseWriter
    @Dependency(\.context) var context
    switch context {
    case .live:
        var defaultPath: String {
            get throws {
                let applicationSupportDirectory = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                return applicationSupportDirectory.appendingPathComponent("SQLiteData.db").absoluteString
            }
        }
        database = try DatabasePool(path: path ?? defaultPath, configuration: configuration)
    case .preview, .test:
        database = try temporaryDatabasePool(configuration: configuration)
    }
    return database
}

extension DependencyValues {
    /// The default database used by `@FetchAll`, `@FetchOne`, and `@Fetch`.
    ///
    /// Configure this as early as possible in your app's lifetime, like the app entry point in
    /// SwiftUI, using `prepareDependencies`:
    ///
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///   init() {
    ///     prepareDependencies {
    ///       // Create database connection and run migrations...
    ///       $0.defaultDatabase = try! DatabaseQueue(/* ... */)
    ///     }
    ///   }
    ///   // ...
    /// }
    /// ```
    ///
    /// > Note: You can only prepare the database a single time in the lifetime of your app.
    /// > Attempting to do so more than once will produce a runtime warning.
    ///
    /// Once configured, access the database anywhere using `@Dependency`:
    ///
    /// ```swift
    /// @Dependency(\.defaultDatabase) var database
    /// ```
    public var defaultDatabase: any DatabaseWriter {
        get { self[DefaultDatabaseKey.self] }
        set { self[DefaultDatabaseKey.self] = newValue }
    }

    private enum DefaultDatabaseKey: DependencyKey {
        static var liveValue: any DatabaseWriter { testValue }
        static var testValue: any DatabaseWriter {
            var message: String {
                @Dependency(\.context) var context
                switch context {
                case .live:
                    return """
                        A blank, in-memory database is being used. To set the database that is used by \
                        'SQLite', use the 'prepareDependencies' tool as early as possible in the lifetime \
                        of your app, such as in your app or scene delegate in UIKit, or the app entry point in \
                        SwiftUI:

                            @main
                            struct MyApp: App {
                              init() {
                                prepareDependencies {
                                  $0.defaultDatabase = try! DatabaseQueue(/* ... */)
                                }
                              }
                              // ...
                            }
                        """

                case .preview:
                    return """
                        A blank, in-memory database is being used. To set the database that is used by \
                        'SQLite' in a preview, use a tool like 'prepareDependencies':

                            #Preview {
                              let _ = prepareDependencies {
                                $0.defaultDatabase = try! DatabaseQueue(/* ... */)
                              }
                              // ...
                            }
                        """

                case .test:
                    return """
                        A blank, in-memory database is being used. To set the database that is used by \
                        'SQLite' in a test, use a tool like the 'dependency' trait from \
                        'DependenciesTestSupport':

                            import DependenciesTestSupport

                            @Suite(.dependency(\\.defaultDatabase, try DatabaseQueue(/* ... */)))
                            struct MyTests {
                              // ...
                            }
                        """
                }
            }
            if shouldReportUnimplemented {
                reportIssue(message)
            }
            var configuration = Configuration()
            #if DEBUG
                configuration.label = .defaultDatabaseLabel
            #endif
            return try! DatabaseQueue(configuration: configuration)
        }
    }
}

#if DEBUG
    extension String {
        package static let defaultDatabaseLabel = "co.pointfree.SQLiteData.testValue"
    }
#endif
