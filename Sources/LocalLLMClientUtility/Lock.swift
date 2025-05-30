#if canImport(os)
import os
#else
import Glibc
#endif

#if canImport(os)
package typealias Lock = OSAllocatedUnfairLock
#else
package final class Lock: @unchecked Sendable {
    @usableFromInline
    let mutex: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: 1)

    package init() {
        let err = pthread_mutex_init(self.mutex, nil)
        precondition(err == 0)
    }

    deinit {
        let err = pthread_mutex_destroy(self.mutex)
        precondition(err == 0)
        mutex.deallocate()
    }

    @usableFromInline
    func lock() {
        let err = pthread_mutex_lock(self.mutex)
        precondition(err == 0)
    }

    @usableFromInline
    func unlock() {
        let err = pthread_mutex_unlock(self.mutex)
        precondition(err == 0)
    }

    @inlinable
    package func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try body()
    }
}
#endif

package final class Locked<Value: ~Copyable> {
    @usableFromInline let lock = Lock()

    @usableFromInline var value: Value
    package init(_ value: consuming sending Value) {
        self.value = value
    }
}

extension Locked where Value: ~Copyable {
    @discardableResult @inlinable
    package borrowing func withLock<Result: ~Copyable, E: Error>(_ block: (inout sending Value) throws(E) -> sending Result) throws(E) -> sending Result {
        lock.lock()
        defer { lock.unlock() }
        return try block(&value)
    }
}

extension Locked: @unchecked Sendable where Value: ~Copyable {
}

extension Locked where Value: Sendable {
    package func exchange(_ newValue: Value) -> Value {
        withLock {
            let old = $0
            $0 = newValue
            return old
        }
    }
}
