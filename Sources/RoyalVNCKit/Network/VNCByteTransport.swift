#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import Dispatch

/// A connected byte stream that carries a `VNCConnection` instead of the TCP
/// connection RoyalVNCKit opens itself, for example a tunnel over SSH.
/// Hand it to `VNCConnection.init(settings:transport:framebufferAllocator:)`.
public protocol VNCByteTransport: AnyObject {
    /// Waits for at least one byte and returns up to `maximumLength` bytes.
    /// Returns no bytes once the stream ended.
    func read(maximumLength: Int) async throws -> Data

    /// Returns once all of `data` was handed to the stream.
    func write(_ data: Data) async throws

    /// Ends the stream. Called once, when the connection disconnects.
    func close()
}

/// Runs a `VNCConnection` over a `VNCByteTransport`. The transport is
/// connected already, so the connection is ready as soon as it starts.
final class ByteTransportNetworkConnection: NetworkConnection {
    private let transport: VNCByteTransport
    private let lock = NSLock()
    private var statusUpdateHandler: NetworkConnectionStatusUpdateHandler?
    private var currentStatus = NetworkConnectionStatus.setup

    init(transport: VNCByteTransport) {
        self.transport = transport
    }

    var status: NetworkConnectionStatus {
        lock.lock()
        defer { lock.unlock() }

        return currentStatus
    }

    var isReady: Bool {
        if case .ready = status {
            return true
        }

        return false
    }

    func setStatusUpdateHandler(_ statusUpdateHandler: NetworkConnectionStatusUpdateHandler?) {
        lock.lock()
        self.statusUpdateHandler = statusUpdateHandler
        lock.unlock()
    }

    func start(queue: DispatchQueue) {
        queue.async { [weak self] in
            self?.update(.ready)
        }
    }

    func cancel() {
        let wasCancelled: Bool

        lock.lock()
        if case .cancelled = currentStatus {
            wasCancelled = true
        } else {
            wasCancelled = false
        }
        lock.unlock()

        guard !wasCancelled else { return }

        transport.close()
        update(.cancelled)
    }

    private func update(_ status: NetworkConnectionStatus) {
        lock.lock()
        currentStatus = status
        let handler = statusUpdateHandler
        lock.unlock()

        handler?(status)
    }
}

extension ByteTransportNetworkConnection: NetworkConnectionReading {
    func read(minimumLength: Int,
              maximumLength: Int) async throws -> Data {
        var data = Data()

        while data.count < max(minimumLength, 1) {
            let chunk = try await transport.read(maximumLength: maximumLength - data.count)

            guard !chunk.isEmpty else {
                throw VNCError.connection(.closed)
            }

            data.append(chunk)
        }

        return data
    }
}

extension ByteTransportNetworkConnection: NetworkConnectionWriting {
    func write(data: Data) async throws {
        try await transport.write(data)
    }
}
