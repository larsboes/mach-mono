//
//  JSONLinesPipeHandler.swift
//  machNotch
//
//  Extracted from NowPlayingController.swift.
//
//  Splits the mediaremote-adapter stream on raw UTF-8 newlines rather than
//  `String.range(of:)`. That call reaches Foundation's locale-aware,
//  grapheme-aware ICU search, which cost ~20 ms on a 1 MiB chunk against
//  ~0.3 ms for this byte scan. The chunks are that big because the adapter
//  inlines base64 artwork in every payload (`NowPlayingPayload.artworkData`).
//

import Foundation

actor JSONLinesPipeHandler {
    private static let newline = UInt8(ascii: "\n")

    private let pipe: Pipe
    private let fileHandle: FileHandle
    private let decoder = JSONDecoder()
    private var buffer: [UInt8] = []

    init() {
        self.pipe = Pipe()
        self.fileHandle = pipe.fileHandleForReading
    }

    func getPipe() -> Pipe {
        return pipe
    }

    func readJSONLines<T: Decodable>(as type: T.Type, onLine: @escaping (T) async -> Void) async {
        do {
            try await self.processLines(as: type) { decodedObject in
                await onLine(decodedObject)
            }
        } catch {
            Logger.log("Error processing JSON stream: \(error)", category: .error)
        }
    }

    private func processLines<T: Decodable>(as type: T.Type, onLine: @escaping (T) async -> Void) async throws {
        while true {
            let data = try await readData()
            guard !data.isEmpty else { break }

            buffer.append(contentsOf: data)
            for line in drainCompleteLines() {
                await processJSONLine(line, as: type, onLine: onLine)
            }
        }
    }

    /// Removes every newline-terminated line from `buffer` and returns them.
    /// The partial tail stays buffered for the next chunk. The buffer is
    /// compacted once per chunk, not once per line — the old implementation
    /// re-allocated the whole remainder per line, making a multi-line chunk
    /// quadratic in its own length.
    private func drainCompleteLines() -> [Data] {
        var lines: [Data] = []
        var lineStart = buffer.startIndex

        while let newlineIndex = buffer[lineStart...].firstIndex(of: Self.newline) {
            if newlineIndex > lineStart {
                lines.append(Data(buffer[lineStart..<newlineIndex]))
            }
            lineStart = buffer.index(after: newlineIndex)
        }

        guard lineStart > buffer.startIndex else { return [] }
        buffer.removeFirst(lineStart - buffer.startIndex)
        return lines
    }

    private func processJSONLine<T: Decodable>(
        _ line: Data, as type: T.Type, onLine: @escaping (T) async -> Void
    ) async {
        do {
            let decodedObject = try decoder.decode(T.self, from: line)
            await onLine(decodedObject)
        } catch {
            // Ignore lines that can't be decoded
        }
    }

    private func readData() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                handle.readabilityHandler = nil
                continuation.resume(returning: data)
            }
        }
    }

    func close() async {
        do {
            fileHandle.readabilityHandler = nil
            try fileHandle.close()
            try pipe.fileHandleForWriting.close()
        } catch {
            Logger.log("Error closing pipe handler: \(error)", category: .error)
        }
    }
}
