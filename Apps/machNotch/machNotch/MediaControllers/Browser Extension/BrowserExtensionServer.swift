//
//  BrowserExtensionServer.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-16.
//

import Foundation
import Network
import Combine

@MainActor
final class BrowserExtensionServer {
    static let shared = BrowserExtensionServer()

    private let port: UInt16 = 19385
    private var listener: NWListener?
    private var activeConnections: [UUID: NWConnection] = [:]

    let statePublisher = PassthroughSubject<BrowserMediaState, Never>()

    init() {}

    func start() {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            let endpointPort = NWEndpoint.Port(rawValue: port) ?? 19385
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: endpointPort)

            let listener = try NWListener(using: parameters, on: endpointPort)
            
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("[BrowserExtensionServer] Listener failed: \(error)")
                }
            }

            listener.start(queue: .main)
            self.listener = listener
            print("[BrowserExtensionServer] Started on port \(port)")
        } catch {
            print("[BrowserExtensionServer] Failed to start listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for connection in activeConnections.values {
            connection.cancel()
        }
        activeConnections.removeAll()
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let id = UUID()
        activeConnections[id] = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.receiveMessage(on: connection, id: id)
                case .failed, .cancelled:
                    self.activeConnections.removeValue(forKey: id)
                default:
                    break
                }
            }
        }
        
        connection.start(queue: .main)
    }

    private func receiveMessage(on connection: NWConnection, id: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let data = data, !data.isEmpty {
                    // First read attempt: is it a WebSocket handshake?
                    if let requestStr = String(data: data, encoding: .utf8), requestStr.contains("Upgrade: websocket") {
                        self.handleWebSocketHandshake(requestStr: requestStr, connection: connection)
                    } else {
                        // It's a WebSocket frame.
                        self.handleWebSocketFrame(data: data)
                    }
                }

                if isComplete || error != nil {
                    connection.cancel()
                    self.activeConnections.removeValue(forKey: id)
                    return
                }

                self.receiveMessage(on: connection, id: id)

            }
        }
    }

    private func handleWebSocketHandshake(requestStr: String, connection: NWConnection) {
        let lines = requestStr.components(separatedBy: "\r\n")
        var secWebSocketKey = ""
        for line in lines {
            if line.lowercased().starts(with: "sec-websocket-key:") {
                secWebSocketKey = line.dropFirst(18).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        guard !secWebSocketKey.isEmpty, let acceptKey = websocketAccept(for: secWebSocketKey) else {
            connection.cancel()
            return
        }

        let response = "HTTP/1.1 101 Switching Protocols\r\n" +
                       "Upgrade: websocket\r\n" +
                       "Connection: Upgrade\r\n" +
                       "Sec-WebSocket-Accept: \(acceptKey)\r\n\r\n"

        let responseData = Data(response.utf8)
        connection.send(content: responseData, completion: .contentProcessed { error in
            if error != nil {
                connection.cancel()
            }
        })
    }

    private func handleWebSocketFrame(data: Data) {
        // Very basic WebSocket unmasking for text frames
        guard data.count > 2 else { return }
        
        let header1 = data[0]
        let header2 = data[1]
        
        _ = (header1 & 0x80) != 0 // isFinal — reserved for future fragmentation support
        let opCode = header1 & 0x0F
        let isMasked = (header2 & 0x80) != 0
        var payloadLength = Int(header2 & 0x7F)
        
        var offset = 2
        
        if payloadLength == 126 {
            guard data.count >= 4 else { return }
            payloadLength = Int(data[2]) << 8 | Int(data[3])
            offset = 4
        } else if payloadLength == 127 {
            // we don't handle very large frames
            return
        }
        
        var maskingKey: [UInt8] = []
        if isMasked {
            guard data.count >= offset + 4 else { return }
            maskingKey = [data[offset], data[offset+1], data[offset+2], data[offset+3]]
            offset += 4
        }
        
        guard data.count >= offset + payloadLength else { return }
        
        var payload = Data(data[offset..<offset+payloadLength])
        if isMasked {
            for i in 0..<payloadLength {
                payload[i] ^= maskingKey[i % 4]
            }
        }
        
        if opCode == 1 { // Text frame
            if String(data: payload, encoding: .utf8) != nil,
               let decoded = try? JSONDecoder().decode(BrowserMediaState.self, from: payload) {
                statePublisher.send(decoded)
            }
        }
    }

    func sendCommand(_ command: BrowserMediaCommand) {
        guard let payload = try? JSONEncoder().encode(command) else { return }
        
        var frame = Data([0x81]) // text frame
        let length = payload.count
        
        if length < 126 {
            frame.append(UInt8(length))
        } else if length <= 65535 {
            frame.append(126)
            let value = UInt16(length).bigEndian
            withUnsafeBytes(of: value) { frame.append(contentsOf: $0) }
        } else {
            // Not supported for this simple server
            return
        }
        
        frame.append(payload)
        
        for connection in activeConnections.values {
            connection.send(content: frame, completion: .contentProcessed { _ in })
        }
    }

    private func websocketAccept(for key: String) -> String? {
        let magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        return insecureSHA1Base64(string: magic)
    }
}

import CryptoKit

private func insecureSHA1Base64(string: String) -> String? {
    guard let data = string.data(using: .utf8) else { return nil }
    let digest = Insecure.SHA1.hash(data: data)
    return Data(digest).base64EncodedString()
}
