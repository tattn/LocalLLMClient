public struct PredictOptions: Sendable {
    public init(parsesSpecial: Bool? = nil) {
        self.parsesSpecial = parsesSpecial
    }

    public var parsesSpecial: Bool?

    public static let `default` = PredictOptions()
}
