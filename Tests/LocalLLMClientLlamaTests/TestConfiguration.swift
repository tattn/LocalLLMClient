import Foundation

// Common test configuration
let disabledTests = ![nil, "Llama"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS_TEST"])