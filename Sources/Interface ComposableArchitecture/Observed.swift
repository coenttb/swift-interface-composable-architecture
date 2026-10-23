/// A state that reads as the value it observes: `store.lists` is `store.value?.lists`. The lookup lives on this protocol,
/// not on the state, so the state's debug snapshot, which copies the state's attributes, has no lookup to answer.
@dynamicMemberLookup
public protocol Observed {
    associatedtype Value
    var value: Value? { get }
}

extension Observed {
    public subscript<Member>(dynamicMember path: KeyPath<Value, Member>) -> Member? {
        value?[keyPath: path]
    }
}
