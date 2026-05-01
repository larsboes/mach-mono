import Foundation
import Network

final class LocalAPIServer {
    private let router: APIRouter
    private let queue = DispatchQueue(label: "me.theboringteam.boringnotch.localapi", qos: .userInitiated)
    private let port: UInt16

    private var listener: NWListener?
    private var webSocketClients: [UUID: WebSocketClient] = [:]
    private let rateLimiter = APIRateLimiter()
    private let auth = APIAuthMiddleware()

    init(router: APIRouter, port: UInt16 = 19384) {
        self.router = router
        self.port = port
    }

    func start() throws {
        guard listener == nil else { return }

        let nwPort = NWEndpoint.Port(rawValue: port) ?? 19384
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: params, on: nwPort)

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("LocalAPI listener failed: \(error)")
            }
        }

        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        webSocketClients.removeAll()
    }

    func broadcast(_ event: APIEventPayload) {
        queue.async { [weak self] in
            self?.webSocketClients.values.forEach { $0.send(event: event) }
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            let chunk = data ?? Data()
            var combined = accumulated
            combined.append(chunk)

            guard let request = HTTPRequestParser.parseIfComplete(combined) else {
                self.receiveRequest(on: connection, accumulated: combined)
                return
            }

            if self.shouldUpgradeToWebSocket(request: request) {
                self.upgradeToWebSocket(connection: connection, request: request)
                return
            }

            // Rate limiting for write endpoints
            if request.method == .post {
                let clientIP = connection.endpoint.debugDescription.components(separatedBy: ":").first ?? "unknown"
                if !self.rateLimiter.isAllowed(client: clientIP) {
                    let tooMany = APIHTTPResponse.json(status: 429, APIResponseEnvelope<APIErrorData>.failure("Rate limit exceeded"))
                    connection.send(content: tooMany.serialized(), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    return
                }
            }

            // Authentication — enforce on write endpoints.
            // Loopback-only binding means GET is safe without auth.
            // POST requires valid bearer token when auth is configured.
            if request.method == .post && !self.auth.authenticate(request) {
                let unauthorized = APIHTTPResponse.json(status: 401, APIResponseEnvelope<APIErrorData>.failure("Unauthorized"))
                connection.send(content: unauthorized.serialized(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            Task {
                let response = await self.router.route(request)
                connection.send(content: response.serialized(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func shouldUpgradeToWebSocket(request: APIRequest) -> Bool {
        request.path == "/api/v1/events"
            && request.headers["upgrade"]?.lowercased() == "websocket"
            && request.headers["connection"]?.lowercased().contains("upgrade") == true
            && request.headers["sec-websocket-key"] != nil
    }

    private func upgradeToWebSocket(connection: NWConnection, request: APIRequest) {
        guard let key = request.headers["sec-websocket-key"],
              let accept = websocketAccept(for: key)
        else {
            let bad = APIHTTPResponse.json(status: 400, APIResponseEnvelope<APIErrorData>.failure("Invalid WebSocket handshake"))
            connection.send(content: bad.serialized(), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        let response = Data(
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n".utf8
        )

        connection.send(content: response, completion: .contentProcessed { [weak self] error in
            guard error == nil, let self = self else {
                connection.cancel()
                return
            }

            let client = WebSocketClient(connection: connection)
            self.webSocketClients[client.id] = client
            client.start { [weak self] in
                self?.queue.async {
                    self?.webSocketClients.removeValue(forKey: client.id)
                }
            }
        })
    }

    private func websocketAccept(for key: String) -> String? {
        let magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        guard let data = magic.data(using: .utf8) else { return nil }
        let digest = SHA1.hash(data: data)
        return Data(digest).base64EncodedString()
    }
}
