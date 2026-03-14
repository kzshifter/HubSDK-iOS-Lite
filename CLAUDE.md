# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HubSDK is a modular Swift SDK for iOS that unifies analytics, advertising, and monetization services under a single API. Documentation and comments are in a mix of Russian and English.

- **Language:** Swift 6.0 (strict concurrency)
- **Platform:** iOS 15.0+
- **Distribution:** Swift Package Manager only (no CocoaPods/Carthage)

## Build Commands

```bash
# Build
swift build

# Resolve dependencies (first time or after Package.swift changes)
swift package resolve
```

There are no tests or linting configured in this repository.

## Architecture

### Module Dependency Graph

```
HubIntegrationCore  (foundation — Event Bus + protocols, no external deps)
    ├── HubSDKCore          (registration engine, depends on HubIntegrationCore)
    ├── HubFacebook         (Facebook SDK)
    ├── HubFirebase         (Firebase Analytics)
    └── HubAnalytics        (universal event tracker via Firebase)

HubSDKCore + HubIntegrationCore
    ├── HubSDKAdapty        (subscriptions, paywalls, onboarding via Adapty)
    ├── HubGoogleAds        (interstitial, rewarded, banner, app-open ads)
    ├── HubAppsflyer        (install attribution)
    └── HubSkarb            (Skarb analytics)
```

### Core Patterns

**Integration registration (`HubSDKCore`):** Singleton `HubSDKCore.shared` acts as a registry. Integrations are registered via `register(_:awaitReady:)`, then started together with `run(with:)`. Access a registered integration's provider via `integration(ofType:)` or typed convenience properties (e.g., `.adapty`, `.googleAds`).

**`HubDependencyIntegration` protocol** (`HubIntegrationCore/StormIntegration.swift`): Every integration module conforms to this. It requires an associated `Provider` type, a static `name`, and a `start()` method. The provider protocol (e.g., `HubSDKAdaptyProviding`, `HubGoogleAdsProviding`) defines the public API that consumers use.

**`AwaitableIntegration` protocol:** Integrations that need async initialization (Adapty, GoogleAds) also conform to this. They expose `isReady` and `onReady` callback. `HubSDKCore.waitUntilReady()` suspends until all awaited integrations signal readiness (or timeout).

**Event Bus (`HubIntegrationCore/EventBus/`):** `HubEventBus.shared` enables decoupled inter-module communication. Modules publish `HubEvent` cases (`.conversionDataReceived`, `.successPurchase`, `.event`) and any `HubEventListener` subscriber receives them. Uses `NSHashTable.weakObjects()` for automatic cleanup.

**Paywall Coordinator (`HubSDKAdapty/Core/Paywall/HubPaywallCoordinator.swift`):** Static `resolve()` for DI setup, then `show()` creates isolated instances per presentation. Supports both Adapty Builder paywalls and local (custom UI) paywalls via `HubLocalPaywallProvider`. Self-retains while presented, auto-releases on dismiss.

### Concurrency Model

All integration protocols and `HubSDKCore` are `@MainActor`-isolated. Public APIs provide both `async` and completion-handler variants. `CheckedContinuation` is used throughout for bridging callback-based SDK APIs to async/await.
