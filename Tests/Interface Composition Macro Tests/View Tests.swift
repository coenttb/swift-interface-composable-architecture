#if os(macOS)
    import Interface_Composition_Macro_Plugin
    import SwiftSyntaxBuilder
    import SwiftSyntaxMacroExpansion
    import SwiftSyntaxMacrosGenericTestSupport
    import Testing

    extension View {
        @Suite struct Tests {
            @Suite struct Unit {}
        }
    }

    extension View.Tests.Unit {
        @Test(arguments: ["Bindable", "SwiftUI.Bindable", "SwiftUI::Bindable"])
        func `bindable inputs wrap the supplied observable`(_ wrapper: String) {
            assertMacroExpansion(
                """
                @View public struct Editor {
                    @\(wrapper) var browser: StoreOf<Browser>
                }
                """,
                expandedSource: """
                    public struct Editor {
                        @\(wrapper)
                        @MainActor var browser: StoreOf<Browser>

                        @MainActor public init(browser: StoreOf<Browser>) {
                            self._browser = SwiftUI.Bindable(browser)
                        }
                    }

                    extension Editor: SwiftUI.View {
                    }
                    """,
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }

        @Test(arguments: [
            ("@Bindable", "var model: Model = Model()", "Bindable inputs cannot declare independent default storage."),
            ("@Bindable", "var model = Model()", "Declare each view input with a name and explicit type."),
            ("@Bindable", "let model: Model", "@Bindable inputs must be stored var properties."),
            ("@Bindable", "var model: Model { fatalError() }", "@Bindable inputs must be stored var properties."),
            ("@Bindable(wrappedValue: Model())", "var model: Model", "@Bindable inputs cannot declare wrapper arguments; supply the observable through the view initializer."),
            (
                "@Other.Bindable", "var model: Model",
                "@View supports @Binding/@Bindable inputs and @State/@FocusState/@AppStorage/@SceneStorage local storage; other attributed inputs require explicit support."
            ),
            (
                "@State @Bindable", "var model: Model",
                "@View supports @Binding/@Bindable inputs and @State/@FocusState/@AppStorage/@SceneStorage local storage; other attributed inputs require explicit support."
            ),
        ])
        func `unsupported bindable declarations are diagnosed`(_ input: (String, String, String)) {
            assertMacroExpansion(
                """
                @View struct Editor {
                    \(input.0)
                    \(input.1)
                }
                """,
                expandedSource: """
                    struct Editor {
                        \(input.0)
                        @MainActor
                        \(input.1)
                    }

                    extension Editor: SwiftUI.View {
                    }
                    """,
                diagnostics: [.init(message: input.2, line: 1, column: 1)],
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }

        @Test func `bindable inputs coexist with injected store and existing wrappers`() {
            assertMacroExpansion(
                """
                @View(Domain.self) struct Editor {
                    @Bindable private var browser: StoreOf<Browser>
                    @Binding var selected: Bool
                    @State private var expanded = false
                    @FocusState private var focused: Bool
                }
                """,
                expandedSource: """
                    struct Editor {
                        @Bindable
                        @MainActor private var browser: StoreOf<Browser>
                        @Binding
                        @MainActor var selected: Bool
                        @State
                        @MainActor private var expanded = false
                        @FocusState
                        @MainActor private var focused: Bool

                        @MainActor @Interface_ComposableArchitecture.Stored<Domain> private var store: ComposableArchitecture2.StoreOf<Domain>

                        @MainActor init(store: ComposableArchitecture2.StoreOf<Domain>, browser: StoreOf<Browser>, selected: SwiftUI.Binding<Bool>) {
                            self._store = Interface_ComposableArchitecture.Stored(wrappedValue: store)
                            self._browser = SwiftUI.Bindable(browser)
                            self._selected = selected
                        }
                    }

                    extension Editor: SwiftUI.View {
                    }
                    """,
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }

        @Test func `bindable cannot replace an injected store`() {
            assertMacroExpansion(
                """
                @View(Domain.self) struct Editor {
                    @Bindable var store: StoreOf<Domain>
                }
                """,
                expandedSource: """
                    struct Editor {
                        @Bindable
                        @MainActor var store: StoreOf<Domain>
                    }

                    extension Editor: SwiftUI.View {
                    }
                    """,
                diagnostics: [.init(message: "@View(Domain.self) supplies store; do not redeclare it.", line: 1, column: 1)],
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }

        @Test(arguments: ["@MainActor", "@Sendable", "@MainActor @Sendable"])
        func `attributed closure inputs are escaping and keep their attributes`(_ attributes: String) {
            assertMacroExpansion(
                """
                @View struct Harvest {
                    private let update: \(attributes) ([Holder]) -> Run
                    let label: String
                }
                """,
                expandedSource: """
                    struct Harvest {
                        @MainActor
                        private let update: \(attributes) ([Holder]) -> Run
                        @MainActor
                        let label: String

                        @MainActor init(update: @escaping \(attributes) ([Holder]) -> Run, label: String) {
                            self.update = update
                            self.label = label
                        }
                    }

                    extension Harvest: SwiftUI.View {
                    }
                    """,
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }

        @Test func `plain closure inputs are escaping`() {
            assertMacroExpansion(
                """
                @View struct Harvest {
                    let update: (Int) -> Void
                }
                """,
                expandedSource: """
                    struct Harvest {
                        @MainActor
                        let update: (Int) -> Void

                        @MainActor init(update: @escaping (Int) -> Void) {
                            self.update = update
                        }
                    }

                    extension Harvest: SwiftUI.View {
                    }
                    """,
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }

        @Test(arguments: ["AppStorage", "SwiftUI.AppStorage", "SceneStorage", "SwiftUI::SceneStorage"])
        func `app and scene storage are local storage outside the initializer`(_ wrapper: String) {
            assertMacroExpansion(
                """
                @View struct Harvest {
                    @\(wrapper)("harvest.expanded") private var expanded = false
                    let label: String
                }
                """,
                expandedSource: """
                    struct Harvest {
                        @\(wrapper)("harvest.expanded")
                        @MainActor private var expanded = false
                        @MainActor
                        let label: String

                        @MainActor init(label: String) {
                            self.label = label
                        }
                    }

                    extension Harvest: SwiftUI.View {
                    }
                    """,
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }

        @Test func `app storage must be private`() {
            assertMacroExpansion(
                """
                @View struct Harvest {
                    @AppStorage("harvest.expanded") var expanded = false
                }
                """,
                expandedSource: """
                    struct Harvest {
                        @AppStorage("harvest.expanded")
                        @MainActor var expanded = false
                    }

                    extension Harvest: SwiftUI.View {
                    }
                    """,
                diagnostics: [.init(message: "@View local state must be private and cannot be named store.", line: 1, column: 1)],
                macroSpecs: ["View": .init(type: View.self, conformances: ["SwiftUI.View"])],
                failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
            )
        }
    }
#endif
