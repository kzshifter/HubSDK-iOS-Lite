import Adapty
import Foundation
import HubSDKAdapty
import UIKit

// ============================================================================
// MARK: - Setup (AppDelegate / DI)
// ============================================================================

/// Call once at app launch after Adapty SDK is initialized.
func setupPaywallCoordinator() {
    HubPaywallCoordinator.resolve(
        sdk: AppDependency.shared.adaptyCore!,
        localPaywallProvider: AppLocalPaywallProvider()
    )
}


// ============================================================================
// MARK: 1. Fire & Forget — самый частый кейс
// ============================================================================

/// Из любого места: кнопка "Get Premium", баннер, ограничение фичи.
/// Координатор сам себя удержит и отпустит после dismiss.
func showPremiumPaywall(from vc: UIViewController) {
    Task { @MainActor in
        try await HubPaywallCoordinator.show(
            placementId: "premium",
            from: vc,
            config: .init(presentType: .present, closeOnSuccess: true)
        ) { action in
            switch action {
            case .close:
                print("Closed")
            case .purchase(let result):
                if result.isPurchaseSuccess {
                    NotificationCenter.default.post(name: .premiumActivated, object: nil)
                }
            case .purchaseFailed(_, let error):
                print("Purchase error: \(error)")
            case .restore(let entry):
                if entry.isActive {
                    NotificationCenter.default.post(name: .premiumActivated, object: nil)
                }
            case .restoreFailed(let error):
                print("Restore error: \(error)")
            }
        }
    }
}


// ============================================================================
// MARK: 2. С контролем dismiss — когда нужно закрыть снаружи
// ============================================================================

@MainActor
final class FeatureGateViewController: UIViewController {
    
    private var paywallCoordinator: HubPaywallCoordinator?
    
    func showPaywall() {
        Task {
            paywallCoordinator = try await HubPaywallCoordinator.show(
                placementId: "feature_gate",
                from: self,
                config: .init(closeOnSuccess: false)  // сами контролируем dismiss
            ) { [weak self] action in
                self?.handleAction(action)
            }
        }
    }
    
    private func handleAction(_ action: HubPaywallCoordinator.Action) {
        switch action {
        case .purchase(let result) where result.isPurchaseSuccess:
            // Анимация успеха → потом dismiss
            showSuccessAnimation {
                self.paywallCoordinator?.dismiss()
                self.paywallCoordinator = nil
                self.unlockFeature()
            }
        case .close:
            paywallCoordinator = nil
        case .purchaseFailed(_, let error):
            showAlert(error: error)
        case .restoreFailed(let error):
            showAlert(error: error)
        default:
            break
        }
    }
    
    private func showSuccessAnimation(completion: @escaping () -> Void) { /* ... */ }
    private func unlockFeature() { /* ... */ }
    private func showAlert(error: Error) { /* ... */ }
}


// ============================================================================
// MARK: 3. С делегатом — для сложных VC с множеством пейволлов
// ============================================================================

@MainActor
final class SettingsViewController: UIViewController {
    
    private var paywallCoordinator: HubPaywallCoordinator?
    
    func showPremium() {
        Task {
            let coordinator = try await HubPaywallCoordinator.show(
                placementId: "settings_premium",
                from: self,
                config: .init(presentType: .present)
            )
            coordinator.delegate = self
            self.paywallCoordinator = coordinator
        }
    }
    
    func showProPlan() {
        Task {
            let coordinator = try await HubPaywallCoordinator.show(
                placementId: "settings_pro",
                from: self,
                config: .init(presentType: .push)
            )
            coordinator.delegate = self
            self.paywallCoordinator = coordinator
        }
    }
}

extension SettingsViewController: HubPaywallCoordinatorDelegate {
    func paywallCoordinator(
        _ coordinator: HubPaywallCoordinator,
        didPerformAction action: HubPaywallCoordinator.Action
    ) {
        switch action {
        case .close:
            paywallCoordinator = nil
        case .purchase(let result) where result.isPurchaseSuccess:
            refreshPremiumUI()
            paywallCoordinator = nil
        case .restore(let entry) where entry.isActive:
            refreshPremiumUI()
            paywallCoordinator = nil
        case .purchaseFailed(_, let error):
            showError(error)
        case .restoreFailed(let error):
            showError(error)
        default:
            break
        }
    }
    
    private func refreshPremiumUI() { /* ... */ }
    private func showError(_ error: Error) { /* ... */ }
}


// ============================================================================
// MARK: 4. Минимальный вызов — дефолты делают всё за тебя
// ============================================================================

/// closeOnSuccess: true (default), presentType: .present (default)
/// Координатор сам закроется после покупки/рестора. Просто вызови и забудь.
func quickShow(from vc: UIViewController) {
    Task { @MainActor in
        try await HubPaywallCoordinator.show(placementId: "premium", from: vc)
    }
}


// MARK: - Helpers

extension Notification.Name {
    static let premiumActivated = Notification.Name("premiumActivated")
}
