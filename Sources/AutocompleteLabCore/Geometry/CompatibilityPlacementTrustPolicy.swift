public struct CompatibilityPlacementTrustPolicy: Equatable, Sendable {
    public init() {}

    public func policy(
        profile: CompatibilityProfile,
        learningAdjustment: CompatibilityLearningAdjustment
    ) -> PlacementTrustPolicy {
        let hasTrustedVisualAdjustment = learningAdjustment.profile?.hasTrustedVisualAdjustment == true
        let isGreenProfile = profile.supportLevel == .green

        return PlacementTrustPolicy(
            allowsLowConfidencePlacement: isGreenProfile || hasTrustedVisualAdjustment,
            allowsSyntheticCaretPlacement: isGreenProfile
                || profile.allowsSyntheticCaretPlacement
                || hasTrustedVisualAdjustment
        )
    }
}
