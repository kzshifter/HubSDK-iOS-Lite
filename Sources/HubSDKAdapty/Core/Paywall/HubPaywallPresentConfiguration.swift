import Foundation

public struct HubPaywallPresentConfiguration: Sendable {
    
    public enum PresentType: Sendable {
        case present
        case push
    }
    
    public let presentType: PresentType
    public let animationEnable: Bool
    public let dismissEnable: Bool
    public let closeOnSuccess: Bool
    
    public init(
        presentType: PresentType = .present,
        animationEnable: Bool = true,
        dismissEnable: Bool = true,
        closeOnSuccess: Bool = true
    ) {
        self.presentType = presentType
        self.animationEnable = animationEnable
        self.dismissEnable = dismissEnable
        self.closeOnSuccess = closeOnSuccess
    }
}
