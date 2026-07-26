import Foundation

extension BLEManager {

    // MARK: - Connection State Access
    //
    // connectedGoPros / connectingGoPros / discoveredGoPros are `@Published` and
    // are read from the CoreBluetooth queue as well as from SwiftUI on main.
    // Swift `Dictionary` is not thread-safe, so that is undefined behaviour, and
    // a decision made from a value read on one queue can be invalidated before
    // the write lands on another.
    //
    // Dispatching only the WRITES to main does not fix either problem — the read
    // still races, and the decision is still stale. What is required is that the
    // whole read-decide-write runs as one block on a single queue. Main is that
    // queue here, since these properties drive SwiftUI and must be published on
    // main regardless.

    /// Run `work` as one atomic block on the state queue (main).
    ///
    /// Always dispatches, even when the caller is already on main. Running inline
    /// on main would be faster, but it makes the order in which blocks land depend
    /// on which thread issued them: work dispatched earlier from the CoreBluetooth
    /// queue would still be waiting while a later main-thread caller executed
    /// immediately, inverting the two. Making each block atomic does not by itself
    /// give a consistent order between blocks — routing every block through the
    /// same FIFO is what does that.
    func onStateQueue(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    /// Trap in debug builds if connection state is touched off the state queue.
    /// This is what stops the discipline from silently eroding: a new call site
    /// that reads a dictionary from a delegate callback fails immediately in
    /// development instead of corrupting memory occasionally in the field.
    func assertOnStateQueue(_ function: StaticString = #function) {
        #if DEBUG
        if !Thread.isMainThread {
            assertionFailure("Connection state touched off the main queue in \(function)")
        }
        #endif
    }
}
