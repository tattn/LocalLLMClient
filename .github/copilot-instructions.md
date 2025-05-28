We follow Apple's Swift API Design Guidelines for naming conventions and code structure.
We use Swift Testing (import Testing) to write tests. Don't use XCTest. Swift Testing is already contained in the current Xcode version.
We follow SOLID principles to ensure our code is modular and maintainable.
For running tests on Apple platforms like macOS and iOS, we use xcodebuild like `xcodebuild test -scheme LocalLLMClient-Package -destination 'platform=macOS'`. Don't use swift test like `swift test` for Apple platforms, as it does not support the same features and capabilities as xcodebuild.
For running tests on other platforms, we use swift test like `swift test`. Don't use xcodebuild for non-Apple platforms, as it is not compatible with them.
