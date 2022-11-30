import SwiftUI
import ComposableArchitecture

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
public struct NBNavigationStackStore<Element: Hashable, Content: View>: View {
  let store: Store<NavigationState<Element>, NavigationState<Element>>
  let content: Content

  public init<Action>(
	_ store: Store<NavigationState<Element>, NavigationAction<Element, Action>>,
	@ViewBuilder content: () -> Content
  ) {
	self.store = store.scope(state: { $0 }, action: { .setPath($0) })
	self.content = content()
  }

  public var body: some View {
		if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
			WithViewStore(self.store, removeDuplicates: Self.isEqual) { _ in
				let path = ViewStore(self.store).binding(send: { $0 })
				NavigationStack(path: path) {
					self.content
				}
			}
		} else {
			WithViewStore(self.store, removeDuplicates: Self.isEqual) { viewStore in
				NavigationController(
					viewStore: viewStore
				) {
					self.content
				}
			}
		}
  }

  private static func isEqual(
	lhs: NavigationState<Element>,
	rhs: NavigationState<Element>
  ) -> Bool {
	guard lhs.count == rhs.count
	else { return false }

	// TODO: memcmp ids and then fallback to comparing enum tags?
	for (lhs, rhs) in zip(lhs, rhs) {
	  guard lhs.id == rhs.id && enumTag(lhs.element) == enumTag(rhs.element)
	  else { return false }
	}
	return true
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension View {
  @ViewBuilder
  public func nbNavigationDestination<State: Hashable, Action, Content: View>(
	store: Store<NavigationState<State>, NavigationAction<State, Action>>,
	@ViewBuilder destination: @escaping (Store<State, Action>) -> Content
  ) -> some View {
	  if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
		  self.navigationDestination(for: NavigationState<State>.Destination.self) { state in
			  IfLetStore(
				store.scope(
					state: returningLastNonNilValue { $0[id: state.id] ?? state.element },
					action: { .element(id: state.id, $0) }
				),
				then: destination
			  )
		  }
	  } else {
		  self.nbNavigationDestination(
			  for: State.self
		  ) { state in
			  let scope = store.scope(
				  state: returningLastNonNilValue { $0[id: state.id] ?? state.element },
				  action: { .element(id: state.id, $0) }
			  )
			  IfLetStore(
				  scope,
				  then: destination
			  )
		  }
	  }
  }
}
