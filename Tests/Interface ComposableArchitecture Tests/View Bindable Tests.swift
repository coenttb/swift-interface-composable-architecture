import ComposableArchitecture
import Interface_ComposableArchitecture
import Observation
import SwiftUI
import Testing

@MainActor
@Suite struct `View bindable inputs` {
    @Test func `observable bindings retain the supplied object across view construction`() {
        let source = BindableSource()
        let view = BindableInput(source: source)
        #expect(view.source === source)
        view.count.wrappedValue = 7
        #expect(source.count == 7)
        let rebuilt = BindableInput(source: source)
        #expect(rebuilt.source === source)
        source.count = 12
        #expect(view.count.wrappedValue == 12)
        #expect(rebuilt.count.wrappedValue == 12)
        let other = BindableSource()
        BindableInput(source: other).count.wrappedValue = 3
        #expect(other.count == 3)
        #expect(source.count == 12)
    }

    @Test func `qualified store bindings write to the original store`() {
        let store = Store(initialState: BindableCounter.State()) { BindableCounter() }
        let view = BindableStoreInput(browser: store)
        let qualified = QualifiedBindableStoreInput(store: store)
        #expect(view.browser === store)
        #expect(qualified.store === store)
        view.count.wrappedValue = 9
        #expect(store.count == 9)
        #expect(qualified.count.wrappedValue == 9)
        qualified.count.wrappedValue = 17
        #expect(store.count == 17)
        #expect(view.count.wrappedValue == 17)
    }
}

@Observable private final class BindableSource { var count = 0 }

@View private struct BindableInput {
    @Bindable var source: BindableSource
    var count: Binding<Int> { $source.count }
    var body: some SwiftUI.View { Stepper("Count", value: $source.count) }
}

@ComposableArchitecture.Feature private struct BindableCounter {
    struct State { var count = 0 }
}

@View private struct BindableStoreInput {
    @SwiftUI.Bindable var browser: StoreOf<BindableCounter>
    @State private var expanded = false
    @FocusState private var focused: Bool
    var count: Binding<Int> { $browser.count }
    var body: some SwiftUI.View { Stepper("Count", value: $browser.count) }
}

@View private struct QualifiedBindableStoreInput {
    @SwiftUI::Bindable var store: StoreOf<BindableCounter>
    var count: Binding<Int> { $store.count }
    var body: some SwiftUI.View { Stepper("Count", value: $store.count) }
}
