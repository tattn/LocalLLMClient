import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A shared handler for managing pause/resume functionality in LLM clients
package actor PauseHandler {
    package private(set) var isPaused = false
    private var pauseContinuations: [CheckedContinuation<Void, Never>] = []
    
    #if canImport(UIKit)
    private final class LifecycleObserver {
        private var observers: [NSObjectProtocol] = []

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func setupObservers(
            willResignActive: @Sendable @escaping () -> Void,
            didBecomeActive: @Sendable @escaping () -> Void
        ) {
            let willResignActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: nil
            ) { _ in
                willResignActive()
            }

            let didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: nil
            ) { _ in
                didBecomeActive()
            }

            observers = [willResignActiveObserver, didBecomeActiveObserver]
        }
    }
    private var notificationObservers = LifecycleObserver()
    #endif
    
    package init(disableAutoPause: Bool = false) {
        #if canImport(UIKit)
        if !disableAutoPause {
            notificationObservers.setupObservers { [weak self] in
                Task {
                    await self?.pause()
                }
            } didBecomeActive: { [weak self] in
                Task {
                    await self?.resume()
                }
            }
        }
        #endif
    }
    
    /// Pauses generation
    package func pause() {
        isPaused = true
    }
    
    /// Resumes generation
    package func resume() {
        isPaused = false
        for continuation in pauseContinuations {
            continuation.resume()
        }
        pauseContinuations.removeAll()
    }
    
    /// Checks if generation is paused and waits if necessary
    package func checkPauseState() async {
        guard isPaused else { return }
        await withCheckedContinuation { continuation in
            pauseContinuations.append(continuation)
        }
    }
}

