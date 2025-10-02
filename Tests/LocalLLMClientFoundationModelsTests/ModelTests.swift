import Testing
import Foundation

private let disabledTests = ProcessInfo.processInfo.environment.keys.contains("GITHUB_ACTIONS_TEST")

@Suite(.serialized, .disabled(if: disabledTests))
struct ModelTests {}
