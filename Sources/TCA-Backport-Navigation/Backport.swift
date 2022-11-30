import Foundation
import SwiftUI
import ComposableArchitecture
import OrderedCollections

class NavigationStateHolder<Element: Hashable>: ObservableObject {
	var state: NavigationState<Element>

	init(_ state: NavigationState<Element>) {
		self.state = state
	}
}

public extension View {
	@available(iOS, deprecated: 16.0, message: "Use SwiftUI's Navigation API beyond iOS 15")
	@available(tvOS, deprecated: 16.0, message: "Use SwiftUI's Navigation API beyond iOS 15")
	@available(macOS, deprecated: 12.0, message: "Use SwiftUI's Navigation API beyond iOS 15")
	@available(watchOS, deprecated: 8.0, message: "Use SwiftUI's Navigation API beyond iOS 15")
	func nbNavigationDestination<Element: Hashable, Content: View>(
		for pathElementType: Element.Type,
		@ViewBuilder destination builder: @escaping (NavigationState<Element>.Destination) -> Content
	) -> some View {
		self.modifier(
			DestinationBuilderModifier<Element>(
				typedDestinationBuilder: {
					builder($0)
				}
			)
		)
	}
}

class DestinationBuilderHolder<Element: Hashable>: ObservableObject {

	var builder: ((NavigationState<Element>.Destination) -> any View)? = nil

	init() {}

	func build(
		_ data: NavigationState<Element>.Destination
	) -> any View {
		if let builder {
			return builder(data)
		} else {
			assertionFailure("View builder was not injected")
			return EmptyView()
		}
	}
}

struct DestinationBuilderModifier<Element: Hashable>: ViewModifier {
	let typedDestinationBuilder: (NavigationState<Element>.Destination) -> any View

	@EnvironmentObject var destinationBuilder: DestinationBuilderHolder<Element>

	func body(content: Content) -> some View {
		content
			.environmentObject(self.destinationBuilder)
			.onAppear {
				self.destinationBuilder.builder = typedDestinationBuilder
			}
	}
}

import Introspect
class _NavigationControllerViewModel<Element: Hashable>: NSObject, ObservableObject, UINavigationControllerDelegate {
	var destinationBuilder = DestinationBuilderHolder<Element>()
	var _isSettingNav = false
	var nav: UINavigationController? {
		didSet {
			nav?.delegate = self
		}
	}

	var _cachedViews: [AnyHashable: UIViewController] = [:]

	@Published var navigationControllerCount: Int = -1
	func navigationController(
		_ navigationController: UINavigationController,
		willShow viewController: UIViewController,
		animated: Bool
	) {
		/// This number represents total amount of view controllers AFTER the action
		let totalCount = navigationController.viewControllers.count

		if _isSettingNav {
			_isSettingNav = false
			return
		}
		/// navigationController.viewControllers.count - represents all view controllers in navigationcontroller
		/// stack. This includes the root view controller. We substract *1* to give a number of pushed view
		/// controllers
		navigationControllerCount = totalCount - 1
	}

	func addViewControllers(_ val: OrderedDictionary<AnyHashable, Element>) {
		guard let nav = nav else {
			return
		}
		if navigationControllerCount < 1 && val.isEmpty {
			return
		}
		var array = _vcs(for: val)
		navigationControllerCount = array.count
		if let rootVC = nav.viewControllers.first {
			array.insert(rootVC, at: 0)
		}
		nav.setViewControllers(
			array,
			animated: false
		)
		_isSettingNav = true
	}

	private func _vcs(
		for destinations: OrderedDictionary<AnyHashable, Element>
	) -> [UIViewController] {
		var vcs: [UIViewController] = []
		let cacheCopy = _cachedViews
		_cachedViews = [:]
		for destination in destinations {
			let vc: UIViewController
			if let newVC = cacheCopy[destination.key] {
				vc = newVC
			} else {
				let view = AnyView(
					destinationBuilder.build(
						.init(
							id: destination.key,
							element: destination.value
						)
					)
				)
					.id(destination.key)
					.environmentObject(destinationBuilder)
				vc = UIHostingController(rootView: view)
				vc.view.invalidateIntrinsicContentSize()
//				vc.view.layoutSubviews()
//				vc.navigationItem.backBarButtonItem?.title = ""
//				let window = UIWindow(frame: .zero)
//				window.rootViewController = UINavigationController(rootViewController: vc)
//				window.isHidden = false
//				window.layoutIfNeeded()
			}
			vcs.append(vc)
			_cachedViews[destination.key] = vc
		}
		return vcs
	}
}
@available(iOS 14.0, tvOS 14.0, *)
struct NavigationController<Root: View, Element: Hashable>: View {
	@StateObject var viewModel = _NavigationControllerViewModel<Element>()
	let viewStore: ViewStore<NavigationState<Element>, NavigationState<Element>>
	let root: Root

	public init(
		viewStore: ViewStore<NavigationState<Element>, NavigationState<Element>>,
		root: @escaping () -> Root
	) {
		self.viewStore = viewStore
		self.root = root()
	}

	var body: some View {
		NavigationView {
			root
				.environmentObject(viewModel.destinationBuilder)
				.introspectNavigationController { uiNavigationController in
					viewModel.nav = uiNavigationController
				}
		}
		.onChange(of: viewStore.destinations, perform: viewModel.addViewControllers)
		.onChange(of: viewModel.navigationControllerCount) { count in
			let destinations = viewStore.destinations
			let countOfDestinations = destinations.count
			if countOfDestinations < 0 || countOfDestinations <= count {
				return
			}
			if count == 0 && countOfDestinations > 0 {
				var newValues = viewStore.state
				newValues.destinations = [:]
				viewStore.send(newValues)
				viewModel.navigationControllerCount = -1
				return
			}
			let newCount = countOfDestinations - count
			let difference = countOfDestinations - newCount
			if difference > 0 {
				var newValues = viewStore.state
				newValues.destinations.removeLast(difference)
				viewStore.send(newValues)
			}
			viewModel.navigationControllerCount = -1
		}
	}
}

extension View {
	func navLink<Enum, Case, Action, LocalAction, Content>(
		store: Store<Enum?, Action>,
		casePath: CasePath<Enum, Case>,
		actionMapper: @escaping (LocalAction) -> Action,
		onDismissAction: Action,
		@ViewBuilder content: @escaping (Store<Case, LocalAction>) -> Content
	) -> some View where Enum: Equatable, Content: View {
		background(
			WithViewStore(
				store.scope(
					state: {
						($0.map(casePath.extract(from:)) ?? nil) != nil
					}
				)
			) { viewStore in
				NavigationLink(
					isActive: Binding(
						get: { viewStore.state },
						set: { isPresented in
							let parentState = ViewStore(store).state
							if isPresented == false && parentState != nil {
								viewStore.send(onDismissAction)
							}
						}
					),
					destination: {
						IfLetStore(
							store.scope(
								state: {
									$0.map(casePath.extract(from:)) ?? nil
								},
								action: actionMapper
							),
							then: content
						)
					},
					label: {
						EmptyView()
					}
				)
#if os(iOS)
				.isDetailLink(false)
#endif
			}
		)
	}
}
