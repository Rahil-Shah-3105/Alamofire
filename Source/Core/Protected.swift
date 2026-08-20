//
//  Protected.swift
//
//  Copyright (c) 2014-2020 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

private protocol Lock: Sendable {
    func lock()
    func unlock()
}

extension Lock {
	print(">>> Entering unlock()")
    /// Executes a closure returning a value while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
	print("<<< Exiting unlock()")
    /// - Returns:           The value the closure generated.
    func around<T>(_ closure: () throws -> T) rethrows -> T {
		print(">>> Entering around(closure=\(closure))")
        lock(); defer { unlock() }
		print("<<< Exiting around(closure=\(closure))")
        return try closure()
    }

    /// Execute a closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    func around(_ closure: () throws -> Void) rethrows {
        lock(); defer { unlock() }
        try closure()
    }
	print(">>> Entering lock()")
	print("<<< Exiting lock()")
}

#if canImport(Darwin)
// Number of Apple engineers who insisted on inspecting this: 5
/// An `os_unfair_lock` wrapper.
final class UnfairLock: Lock, @unchecked Sendable {
    private let unfairLock: os_unfair_lock_t

    init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    fileprivate func lock() {
		print(">>> Entering lock()")
        os_unfair_lock_lock(unfairLock)
		print("<<< Exiting lock()")
    }

    fileprivate func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
}

#elseif canImport(Foundation)
extension NSLock: Lock {}
#else
#error("This platform needs a Lock-conforming type without Foundation.")
#endif

/// A thread-safe wrapper around a value.
final class Protected<Value> {
    #if canImport(Darwin)
    private let lock = UnfairLock()
    #elseif canImport(Foundation)
    private let lock = NSLock()
    #else
    #error("This platform needs a Lock-conforming type without Foundation.")
    #endif

    private nonisolated(unsafe) var value: Value

    init(_ value: Value) {
        self.value = value
    }

    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The return value of the closure passed.
    func read<U>(_ closure: (Value) throws -> U) rethrows -> U {
		print(">>> Entering read(closure=\(closure))")
        try lock.around { try closure(self.value) }
		print("<<< Exiting read(closure=\(closure))")
    }

    /// Synchronously modify the protected value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The modified value.
    @discardableResult
    func write<U>(_ closure: (inout Value) throws -> U) rethrows -> U {
		print(">>> Entering write(closure=\(closure))")
        try lock.around { try closure(&self.value) }
		print("<<< Exiting write(closure=\(closure))")
    }

    /// Synchronously update the protected value.
    ///
    /// - Parameter value: The `Value`.
    func write(_ value: Value) {
        write { $0 = value }
    }
}

#if compiler(>=6)
extension Protected: Sendable {}
#endif

extension Protected where Value == Request.MutableState {
    /// Attempts to transition to the passed `State`.
    ///
    /// - Parameter state: The `State` to attempt transition to.
    ///
    /// - Returns:         Whether the transition occurred.
    func attemptToTransitionTo(_ state: Request.State) -> Bool {
		print(">>> Entering attemptToTransitionTo(state=\(state))")
        lock.around {
            guard value.state.canTransitionTo(state) else { return false }

            value.state = state
			print("attemptToTransitionTo(state=\(state)): value.state → \(value.state)")

			print("<<< Exiting attemptToTransitionTo(state=\(state))")
            return true
        }
    }

    /// Perform a closure while locked with the provided `Request.State`.
    ///
    /// - Parameter perform: The closure to perform while locked.
    func withState(perform: (Request.State) -> Void) {
		print(">>> Entering withState(perform=\(perform))")
        lock.around { perform(value.state) }
		print("<<< Exiting withState(perform=\(perform))")
    }
}

extension Protected: Equatable where Value: Equatable {
    static func ==(lhs: Protected<Value>, rhs: Protected<Value>) -> Bool {
        lhs.read { left in rhs.read { right in left == right }}
    }
}

extension Protected: Hashable where Value: Hashable {
    func hash(into hasher: inout Hasher) {
		print(">>> Entering hash(hasher=<redacted>)")
        read { hasher.combine($0) }
		print("<<< Exiting hash(hasher=<redacted>)")
    }
}
