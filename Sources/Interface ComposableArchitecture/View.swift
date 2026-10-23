public import CasePaths
public import ComposableArchitecture
public import SwiftUI

/// Derive construction from a view's input product. An optional feature argument
/// supplies its existing store and bindings; it never creates a feature or store.
/// Stored `@Bindable` inputs accept the original observable object, preserving its
/// identity and exposing SwiftUI bindings without introducing view-owned state.
@attached(memberAttribute)
@attached(extension, conformances: SwiftUI.View)
@attached(member, names: named(store), named(_store), named($store), named(init))
public macro View(_ feature: Any.Type? = nil) =
    #externalMacro(
        module: "Interface_Composition_Macro_Plugin",
        type: "View"
    )

/// Inject one existing store. Reading it participates in SwiftUI observation;
/// its projection composes the feature's declared child coordinates.
@propertyWrapper @MainActor
public struct Stored<Domain: FeatureProtocol>: DynamicProperty {
    public let wrappedValue: StoreOf<Domain>
    public nonisolated init(wrappedValue: StoreOf<Domain>) { self.wrappedValue = wrappedValue }
    public var projectedValue: Bindings<Domain.State, Domain.Action> { .init(wrappedValue) }
}

/// A coordinate adapter around the same store, not a second state representation.
@dynamicMemberLookup @MainActor
public struct Bindings<State, Action> {
    private let store: Store<State, Action>
    public init(_ store: Store<State, Action>) { self.store = store }

    @_disfavoredOverload
    public subscript<Member>(dynamicMember path: WritableKeyPath<State, Member>) -> Binding<Member> {
        Bindable(store)[dynamicMember: path]
    }

    public subscript<Scope: ScopePath, Projection: Lens, Path: CasePath>(
        dynamicMember path: KeyPath<State.Feature.Scopes, Scope>
    ) -> Binding<Store<Editing<Projection>.State, Editing<Projection>.Action>?>
    where
        State: _FeatureState,
        State.Feature: FeatureProtocol<State, Action>,
        Scope.StatePath: WritableKeyPath<State, Editing<Projection>.State?>,
        Scope.ActionPath: CaseKeyPath<Action, Path>,
        Path.Value == Editing<Projection>.Action
    {
        Bindable(store).scope(path)
    }

    public func presenting<Scope: ScopePath, ChildState, Path: CasePath>(
        _ path: KeyPath<State.Feature.Scopes, Scope>
    ) -> Binding<Store<ChildState, Path.Value>?>
    where
        State: _FeatureState,
        State.Feature: FeatureProtocol<State, Action>,
        Scope.StatePath: WritableKeyPath<State, ChildState?>,
        Scope.ActionPath: CaseKeyPath<Action, Path>
    {
        Bindable(store).scope(path)
    }
}

extension Bindings where State: Composite, Action == State.Bindings.Action {
    public subscript<Member>(dynamicMember path: KeyPath<State.Bindings, Member>) -> Member {
        State.Bindings(store)[keyPath: path]
    }
}

/// Public spelling used by generated projections without requiring consumers to
/// import SwiftUI in the domain's Feature target.
public typealias Presentation<State, Action> = Binding<Store<State, Action>?>

extension SwiftUI.View {
    /// Explicit UI policy: request focus when this field enters the view tree.
    public func focusOnPresentation() -> some SwiftUI.View {
        modifier(Focus())
    }
}

private struct Focus: ViewModifier {
    @FocusState private var focused: Bool
    func body(content: Content) -> some SwiftUI.View {
        content.focused($focused).onAppear { focused = true }
    }
}
