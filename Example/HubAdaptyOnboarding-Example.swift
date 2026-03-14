import Adapty
import AdaptyUI
import UIKit
import SwiftUI

// ============================================================================
// MARK: - Usage Examples: HubSDK Onboarding Integration
// ============================================================================

// MARK: 1. Async/Await — UIKit (Recommended)

/// Самый простой способ показать онборд из UIKit ViewController.
final class OnboardingExampleViewController: UIViewController {
    
    private let adapty: HubSDKOnboardingProviding
    
    // держим strong reference на proxy, иначе делегат умрёт
    private var delegateProxy: OnboardingDelegateProxy?
    
    init(adapty: HubSDKOnboardingProviding) {
        self.adapty = adapty
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Simple Presentation
    
    /// Показ онборда с closure-based API (без ручного делегата)
    func showOnboarding() {
        Task { @MainActor in
            do {
                let (controller, proxy) = try await adapty.onboardingController(
                    for: "onboarding_main",
                    locale: nil,
                    placeholder: {
                        // Кастомный splash/loading пока грузится онборд
                        let view = UIView()
                        view.backgroundColor = .black
                        return view
                    },
                    onAction: { [weak self] action in
                        self?.handleOnboardingAction(action)
                    }
                )
                
                // Сохраняем proxy чтобы не сдох делегат
                self.delegateProxy = proxy
                
                controller.modalPresentationStyle = .fullScreen
                present(controller, animated: true)
                
            } catch {
                print("Failed to show onboarding: \(error)")
            }
        }
    }
    
    // MARK: - With Traditional Delegate
    
    /// Показ онборда через классический делегат
    func showOnboardingWithDelegate() {
        Task { @MainActor in
            do {
                let controller = try await adapty.onboardingController(
                    for: "onboarding_main",
                    delegate: self
                )
                
                controller.modalPresentationStyle = .fullScreen
                present(controller, animated: true)
            } catch {
                print("Failed to show onboarding: \(error)")
            }
        }
    }
    
    // MARK: - Action Handling
    
    private func handleOnboardingAction(_ action: OnboardingAction) {
        switch action {
        case .close:
            dismiss(animated: true) {
                // Переход на главный экран или показ пейволла
            }
            
        case .openPaywall(let paywallAction):
            // actionId == placementId пейволла (рекомендация Adapty)
            dismiss(animated: true) {
                self.presentPaywall(placementId: paywallAction.actionId)
            }
            
        case .custom(let customAction):
            switch customAction.actionId {
            case "allowNotifications":
                requestNotificationPermission()
            case "enableTracking":
                requestATTPermission()
            default:
                print("Unhandled custom action: \(customAction.actionId)")
            }
            
        case .stateUpdated(let stateAction):
            handleUserInput(stateAction)
            
        case .analytics(let event):
            trackAnalytics(event)
            
        case .didFinishLoading:
            print("Onboarding loaded and ready")
            
        case .error(let error):
            print("Onboarding error: \(error)")
        }
    }
    
    // MARK: - User Input Processing
    
    private func handleUserInput(_ action: AdaptyOnboardingsStateUpdatedAction) {
        switch action.params {
        case .select(let params):
            // Квиз: один ответ
            print("Selected: \(params.value.value) for element: \(action.elementId)")
            
            // Сохраняем как custom attribute для таргетинга пейволлов
            Task {
                let builder = AdaptyProfileParameters.Builder()
                try? builder.with(customAttribute: params.value.value, forKey: action.elementId)
                try? await Adapty.updateProfile(params: builder.build())
            }
            
        case .multiSelect(let params):
            // Квиз: несколько ответов
            let values = params.value.map(\.value)
            print("Multi-selected: \(values) for element: \(action.elementId)")
            
        case .input(let params):
            // Текстовый ввод (имя, email)
            let text = params.value.value
            
            Task {
                let builder = AdaptyProfileParameters.Builder()
                switch action.elementId {
                case "name":
                    builder.with(firstName: text)
                case "email":
                    builder.with(email: text)
                default:
                    break
                }
                try? await Adapty.updateProfile(params: builder.build())
            }
            
        case .datePicker(let params):
            print("Date: \(params.value.day)/\(params.value.month)/\(params.value.year)")
        }
    }
    
    // MARK: - Helpers
    
    private func presentPaywall(placementId: String) {
        // Используй свой существующий флоу через adapty.placementEntry
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func requestATTPermission() {
        // ATTrackingManager.requestTrackingAuthorization { _ in }
    }
    
    private func trackAnalytics(_ event: AdaptyOnboardingsAnalyticsEvent) {
        // Отправка в AppsFlyer / Firebase / etc.
    }
}

// MARK: - Traditional Delegate Conformance

extension OnboardingExampleViewController: AdaptyOnboardingControllerDelegate {
    
    func onboardingController(
        _ controller: AdaptyOnboardingController,
        onCloseAction action: AdaptyOnboardingsCloseAction
    ) {
        controller.dismiss(animated: true)
    }
    
    func onboardingController(
        _ controller: AdaptyOnboardingController,
        onCustomAction action: AdaptyOnboardingsCustomAction
    ) {
        // Handle custom actions
    }
    
    func onboardingController(
        _ controller: AdaptyOnboardingController,
        onPaywallAction action: AdaptyOnboardingsOpenPaywallAction
    ) {
        controller.dismiss(animated: true) {
            self.presentPaywall(placementId: action.actionId)
        }
    }
    
    func onboardingController(
        _ controller: AdaptyOnboardingController,
        onStateUpdatedAction action: AdaptyOnboardingsStateUpdatedAction
    ) {
        handleUserInput(action)
    }
    
    func onboardingController(
        _ controller: AdaptyOnboardingController,
        didFailWithError error: AdaptyUIError
    ) {
        print("Error: \(error)")
    }
    
    func onboardingController(
        _ controller: AdaptyOnboardingController,
        onAnalyticsEvent event: AdaptyOnboardingsAnalyticsEvent
    ) {
        trackAnalytics(event)
    }
}


// ============================================================================
// MARK: 2. Async/Await — Fetch Only (Manual Control)
// ============================================================================

/// Когда нужен полный контроль — получаем entry и сами строим контроллер.
func manualOnboardingFlow(adapty: HubSDKOnboardingProviding) async throws {
    
    // Шаг 1: Получаем OnboardingEntry
    let entry = try await adapty.onboardingEntry(for: "onboarding_main")
    
    // Шаг 2: Создаём контроллер вручную
    let controller = try AdaptyUI.onboardingController(
        with: entry.configuration,
        delegate: /* your delegate */
    )
    
    // Шаг 3: Показываем
    await MainActor.run {
        // present(controller, animated: true)
    }
}


// ============================================================================
// MARK: 3. Completion Handler — UIKit (Legacy / ObjC compat)
// ============================================================================

/// Для кода где нет async/await (старые ViewControllers, ObjC bridges)
func showOnboardingWithCompletion(adapty: HubSDKOnboardingProviding) {
    adapty.onboardingEntry(for: "onboarding_main") { result in
        switch result {
        case .success(let entry):
            do {
                let proxy = OnboardingDelegateProxy(
                    onAction: { action in
                        switch action {
                        case .close:
                            // dismiss
                            break
                        default:
                            break
                        }
                    }
                )
                
                let controller = try AdaptyUI.onboardingController(
                    with: entry.configuration,
                    delegate: proxy
                )
                
                // Сохрани proxy! Иначе делегат не будет работать
                // self.delegateProxy = proxy
                
                controller.modalPresentationStyle = .fullScreen
                // self.present(controller, animated: true)
                
            } catch {
                print("Configuration error: \(error)")
            }
            
        case .failure(let error):
            print("Fetch error: \(error)")
        }
    }
}


// ============================================================================
// MARK: 4. SwiftUI Integration
// ============================================================================

/// SwiftUI враппер для показа онборда.
@available(iOS 16.0, *)
struct OnboardingSwiftUIExample: View {
    
    let adapty: HubSDKOnboardingProviding
    
    @State private var onboardingConfiguration: AdaptyUI.OnboardingConfiguration?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if let configuration = onboardingConfiguration {
                AdaptyOnboardingView(
                    configuration: configuration,
                    placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                    },
                    onCloseAction: { _ in
                        // Dismiss or navigate
                    },
                    onError: { error in
                        print("Onboarding error: \(error)")
                    }
                )
            } else if isLoading {
                ProgressView("Loading onboarding...")
            } else if let error {
                Text("Error: \(error.localizedDescription)")
            }
        }
        .task {
            await loadOnboarding()
        }
    }
    
    private func loadOnboarding() async {
        do {
            let entry = try await adapty.onboardingEntry(for: "onboarding_main")
            onboardingConfiguration = entry.configuration
        } catch {
            self.error = error
        }
        isLoading = false
    }
}


// ============================================================================
// MARK: 5. Default Audience (Fast Loading)
// ============================================================================

/// Быстрая загрузка для All Users аудитории.
/// Используй когда скорость важнее персонализации.
func showDefaultAudienceOnboarding(adapty: HubSDKOnboardingProviding) async throws {
    let entry = try await adapty.onboardingEntryForDefaultAudience(for: "onboarding_main")
    
    // entry.configuration уже готова к показу
    let controller = try AdaptyUI.onboardingController(
        with: entry.configuration,
        delegate: /* your delegate */
    )
    
    // present(controller, animated: true)
}
