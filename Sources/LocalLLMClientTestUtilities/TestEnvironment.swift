import Foundation

public enum TestEnvironment {
    public static var onGitHubAction: Bool {
        ProcessInfo.processInfo.environment["GITHUB_MODEL_CACHE"] != nil
    }
}
