import Foundation
import Adapty
import AdaptyUI
import UIKit

// MARK: - HubSDKAdapty + Onboarding

extension HubSDKAdapty {
    
    // MARK: Async Fetch
    
    public func onboardingEntry(
        for placementId: String,
        locale: String?
    ) async throws -> OnboardingEntry {
        let (config, _) = try ensureReady()
        let resolvedLocale = locale ?? config.languageCode
        
        do {
            let onboarding = try await Adapty.getOnboarding(
                placementId: placementId,
                locale: resolvedLocale
            )
            
            let configuration = try await AdaptyUI.getOnboardingConfiguration(
                forOnboarding: onboarding
            )
            
            return OnboardingEntry(
                placementId: placementId,
                onboarding: onboarding,
                configuration: configuration
            )
        } catch let error as AdaptyError {
            throw HubSDKError.onboardingFetchFailed(placementId: placementId, underlyingError: error)
        } catch {
            throw HubSDKError.onboardingConfigurationFailed(placementId: placementId, underlyingError: error)
        }
    }
    
    public func onboardingEntryForDefaultAudience(
        for placementId: String,
        locale: String?
    ) async throws -> OnboardingEntry {
        let (config, _) = try ensureReady()
        let resolvedLocale = locale ?? config.languageCode
        
        do {
            let onboarding = try await Adapty.getOnboardingForDefaultAudience(
                placementId: placementId,
                locale: resolvedLocale
            )
            
            let configuration = try await AdaptyUI.getOnboardingConfiguration(
                forOnboarding: onboarding
            )
            
            return OnboardingEntry(
                placementId: placementId,
                onboarding: onboarding,
                configuration: configuration
            )
        } catch let error as AdaptyError {
            throw HubSDKError.onboardingFetchFailed(placementId: placementId, underlyingError: error)
        } catch {
            throw HubSDKError.onboardingConfigurationFailed(placementId: placementId, underlyingError: error)
        }
    }
    
    // MARK: Controller Creation
    
    @MainActor
    public func onboardingController(
        for placementId: String,
        delegate: AdaptyOnboardingControllerDelegate,
        locale: String?
    ) async throws -> AdaptyOnboardingController {
        let entry = try await onboardingEntry(for: placementId, locale: locale)
        
        let controller = try AdaptyUI.onboardingController(
            with: entry.configuration,
            delegate: delegate
        )
        
        return controller
    }
    
    @MainActor
    public func onboardingController(
        for placementId: String,
        locale: String?,
        placeholder: (@MainActor @Sendable () -> UIView?)?,
        onAction: @MainActor @Sendable @escaping (OnboardingAction) -> Void
    ) async throws -> (AdaptyOnboardingController, OnboardingDelegateProxy) {
        let entry = try await onboardingEntry(for: placementId, locale: locale)
        
        let proxy = OnboardingDelegateProxy(
            onAction: onAction,
            placeholder: placeholder
        )

        let controller = try AdaptyUI.onboardingController(
            with: entry.configuration,
            delegate: proxy
        )
        
        return (controller, proxy)
    }
    
    // MARK: Completion Handlers
    
    nonisolated public func onboardingEntry(
        for placementId: String,
        locale: String?,
        completion: @MainActor @Sendable @escaping (Result<OnboardingEntry, Error>) -> Void
    ) {
        Task {
            do {
                let entry = try await onboardingEntry(for: placementId, locale: locale)
                await MainActor.run { completion(.success(entry)) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }
}

