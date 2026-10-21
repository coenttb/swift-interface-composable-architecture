public import ComposableArchitecture2
public import Dependencies
public import Interface_Macro
public import Operation
public import SwiftUI

// An operation followed: `value` is the latest element of the sequence the operation yields for `request`,
// and a new request restarts it. `Observing(reminders.read.page)` selects the domain's canonical primary
// operation; its existing owner supplies the implementation. The first element for a request lands as it is; every
// later one lands in the animation the feature tree declares with `animation(_:)`, as sqlite-data's animated fetches
// do; without one, each lands as it comes. A request for the list already shown, arranged another way, is named with
// `list(_:)`, and its first element lands in the animation too.
@ComposableArchitecture2.Feature public struct Observing<Symbol: Operation::Operation.Operable>
where
    Symbol.Input: Swift.Copyable & Swift.Escapable & Swift.Equatable,
    Symbol.Output: AsyncSequence,
    Symbol.Output.Element: Swift.Copyable & Swift.Escapable
{
    // The state reads as its value: `store.overview.lists` is `store.overview.value?.lists`.
    @dynamicMemberLookup
    public struct State {
        public var request: Symbol.Input
        public var value: Symbol.Output.Element?
        /// The request `value` answers.
        public var answered: Symbol.Input?

        public init(_ request: Symbol.Input, value: Symbol.Output.Element? = nil) {
            self.request = request
            self.value = value
        }

        // A one-field input is named by its field: `State(.list(id))` observes the page of that list.
        public init(_ field: Symbol.Input.Field) where Symbol.Input: Operation::Operation.Unary {
            self.request = .init(field)
        }

        public subscript<Member>(dynamicMember keyPath: KeyPath<Symbol.Output.Element, Member>) -> Member? {
            value?[keyPath: keyPath]
        }
    }

    public typealias Action = Never

    let observe: (Symbol.Input) async throws -> Symbol.Output
    // Whether a new request asks for the same list as the one answered; none does unless `list(_:)` says so.
    private var same: (Symbol.Input, Symbol.Input) -> Bool = { _, _ in false }
    @FeatureEnvironment(Delivery.self) private var animation

    public init(_ observe: @escaping (Symbol.Input) async throws -> Symbol.Output) {
        self.observe = observe
    }

    public init(_ owner: Symbol.Owner) {
        self.observe = { try await Symbol.run(owner, $0) }
    }

    /// Infer the canonical primary operation from the domain value. The operation
    /// symbol remains an implementation detail of this interpretation.
    public init<Domain: Interface.Primary>(_ domain: Domain) where Symbol == Domain.Primary {
        self.observe = { try await Symbol.run(domain, $0) }
    }

    // The owner is read from the dependencies each time the request is observed.
    public init(_ path: any KeyPath<DependencyValues, Symbol.Owner> & Sendable) {
        self.observe = { try await Symbol.run(Dependency(path).wrappedValue, $0) }
    }

    public var body: some ComposableArchitecture2.FeatureProtocol<State, Action> {
        ComposableArchitecture2.EmptyFeature()
            .onChange(of: store.request, initial: true) { _, request, state in
                // Measured against the answer on screen, not the request before, which may never have been answered.
                let arranged = state.answered.map { same($0, request) } ?? false
                store.addTask {
                    var answered = arranged
                    for try await value in try await observe(request) {
                        // The first answer to a request for another list lands as it is: it is a new list. Later
                        // answers are the store changing under the same request, and land in the animation, as does
                        // the first one for the list on screen arranged another way.
                        if answered {
                            try withAnimation(animation) { _ = try store.modify { $0.value = value; $0.answered = request } }
                        } else {
                            _ = try store.modify { $0.value = value; $0.answered = request }
                            answered = true
                        }
                    }
                }
            }
    }
}

extension Observing {
    /// Names the list a request asks for. A new request for the same list, such as another order or filter, lands its
    /// first answer in the declared animation, so the rows move into place; a request for another list lands as it is.
    public func list<List: Equatable>(_ list: @escaping (Symbol.Input) -> List) -> Self {
        var observing = self
        observing.same = { list($0) == list($1) }
        return observing
    }
}

extension FeatureProtocol {
    /// What every observation within this feature delivers lands in `animation`, as a binding's `animation()` lands
    /// what it sets. `animation()` names no SwiftUI type, so a Feature target need not import SwiftUI to animate.
    public func animation(_ animation: SwiftUI.Animation? = .default) -> some Feature {
        self.transformEnvironment { $0[Delivery.self] = animation }
    }
}

private enum Delivery: FeatureEnvironmentKey {
    static var liveValue: SwiftUI.Animation? { nil }
    static var testValue: SwiftUI.Animation? { nil }
}
