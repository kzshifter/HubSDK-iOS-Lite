import UIKit

/// A container that decouples the paywall view controller from the state delegate.
///
/// This allows any architecture (MVC, MVVM, Coordinator, VIPER, SwiftUI) to provide
/// a local paywall without forcing `UIViewController` to also be the `HubLocalPaywallStateDelegate`.
///
/// ## Examples
///
/// **MVVM / SwiftUI** — ViewModel receives state callbacks:
/// ```swift
/// let vm = PaywallViewModel(products: products, delegate: delegate)
/// let vc = UIHostingController(rootView: PaywallView(viewModel: vm))
/// return HubLocalPaywallHandle(viewController: vc, stateDelegate: vm)
/// ```
///
/// **MVC** — ViewController handles everything:
/// ```swift
/// let vc = PaywallViewController(products: products, delegate: delegate)
/// return HubLocalPaywallHandle(viewController: vc, stateDelegate: vc)
/// ```
///
/// **Coordinator** — custom dismiss logic:
/// ```swift
/// let handle = HubLocalPaywallHandle(viewController: vc, stateDelegate: vm)
/// handle.onDismiss = { [weak coordinator] in coordinator?.finish() }
/// return handle
/// ```
@MainActor
public final class HubLocalPaywallHandle {

    /// The view controller to present.
    public let viewController: UIViewController

    /// The object that receives purchase/restore result callbacks.
    /// Can be the VC itself, a ViewModel, Presenter, Coordinator — any `AnyObject`.
    /// If `nil`, results are only reported through `HubPaywallCoordinator.Action`.
    ///
    /// - Important: This reference is `weak`. The caller must ensure the delegate is retained
    ///   elsewhere (e.g., by the view controller, view hierarchy, or a strong reference in the provider).
    public weak var stateDelegate: (any HubLocalPaywallStateDelegate)?

    /// Custom dismiss handler. When set, the coordinator calls this **instead of**
    /// its default `dismiss(animated:)` / `popViewController(animated:)`.
    /// Use this when your architecture manages its own navigation (e.g., coordinator pattern).
    ///
    /// - Important: The closure **must** remove the view controller from the screen itself,
    ///   because the coordinator's standard dismiss logic is skipped entirely.
    public var onDismiss: (() -> Void)?

    public init(
        viewController: UIViewController,
        stateDelegate: (any HubLocalPaywallStateDelegate)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.viewController = viewController
        self.stateDelegate = stateDelegate
        self.onDismiss = onDismiss
    }
}
