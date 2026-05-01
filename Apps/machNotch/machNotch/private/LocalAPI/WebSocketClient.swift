import Foundation
import Network

final class WebSocketClient {
    let id = UUID()
    private let connection: NWConnection

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start(onClose: @escaping () -> Void) {
        receiveLoop(onClose: onClose)
    }

    func send(event: APIEventPayload) {
        let encoder = JSONEncoder()
        guard let payload = try? encoder.encode(event) else { return }
        sendTextFrame(payload)
    }

    private func sendTextFrame(_ payload: Data) {
        var frame = Data([0x81])
        appendLength(payload.count, to: &frame)
        frame.append(payload)

        connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    private func appendLength(_ length: Int, to frame: inout Data) {
        if length < 126 {
            frame.append(UInt8(length))
            return
        }

        if length <= 65_535 {
            frame.append(126)
            let value = UInt16(length).bigEndian
            withUnsafeBytes(of: value) { frame.append(contentsOf: $0) }
            return
        }

        frame.append(127)
        let value = UInt64(length).bigEndian
        withUnsafeBytes(of: value) { frame.append(contentsOf: $0) }
    }

    private func receiveLoop(onClose: @escaping () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] _, _, isComplete, error in
            guard self != nil else { return }
            if isComplete || error != nil {
                onClose()
                return
            }
            self?.receiveLoop(onClose: onClose)
        }
    }
}
