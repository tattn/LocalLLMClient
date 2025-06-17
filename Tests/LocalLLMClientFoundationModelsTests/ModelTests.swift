import Testing
import Foundation

private let disabledTests = ![nil, "FoundationModels"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])

@Suite(.serialized, .disabled(if: disabledTests))
struct ModelTests {}
