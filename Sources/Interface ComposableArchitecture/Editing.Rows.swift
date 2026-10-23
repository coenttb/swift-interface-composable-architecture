public import ComposableArchitecture
public import SwiftUI

/// Only presentation: identity-based substitution and explicit insertion placement.
/// Observation, commands, and the session's commit policy are owned elsewhere.
extension Editing {
    @MainActor
    public struct Rows<Row: SwiftUI.View, Editor: SwiftUI.View>: SwiftUI.View {
        public enum Insertion { case beforeFirst, afterLast }
        private let rows: [Projection.Record]
        @Binding private var editing: Store<Editing<Projection>.State, Editing<Projection>.Action>?
        private let insertion: Insertion
        private let row: (Projection.Record) -> Row
        private let editor: (Binding<Projection.Draft>, @escaping () -> Void) -> Editor

        public init(
            _ rows: [Projection.Record],
            editing: Binding<Store<Editing<Projection>.State, Editing<Projection>.Action>?>,
            insertion: Insertion,
            @ViewBuilder row: @escaping (Projection.Record) -> Row,
            @ViewBuilder editor: @escaping (Binding<Projection.Draft>, @escaping () -> Void) -> Editor
        ) {
            self.rows = rows
            self._editing = editing
            self.insertion = insertion
            self.row = row
            self.editor = editor
        }

        public var body: some SwiftUI.View {
            if insertion == .beforeFirst { newEditor }
            ForEach(rows) { value in
                if let editing, editing.state.id == value.id { content(editing).id(value.id) } else { row(value) }
            }
            if insertion == .afterLast { newEditor }
        }

        @ViewBuilder private var newEditor: some SwiftUI.View {
            if let editing, editing.state.original == nil { content(editing) }
        }

        private func content(_ editing: Store<Editing<Projection>.State, Editing<Projection>.Action>) -> Editor {
            editor(Bindable(editing).draft, { editing.dismiss() })
        }
    }
}
