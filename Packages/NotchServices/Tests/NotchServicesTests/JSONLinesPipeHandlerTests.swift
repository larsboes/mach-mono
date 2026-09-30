import XCTest

@testable import NotchServices

/// Guards the line splitter that reads the mediaremote-adapter stream. It was
/// rewritten from `String.range(of:)` onto a UTF-8 byte scan, so the framing
/// rules it has to keep are pinned here: chunk boundaries fall anywhere,
/// artwork payloads are large, and a malformed line must not eat the stream.
final class JSONLinesPipeHandlerTests: XCTestCase {

    private struct Item: Codable, Equatable {
        let index: Int
        let body: String?
    }

    private actor Collected {
        private(set) var items: [Item] = []
        func append(_ item: Item) { items.append(item) }
    }

    /// Feeds `chunks` through the pipe in order, then closes it and returns
    /// everything the handler decoded.
    private func run(chunks: [String]) async -> [Item] {
        let handler = JSONLinesPipeHandler()
        let pipe = await handler.getPipe()
        let collected = Collected()

        let reading = Task {
            await handler.readJSONLines(as: Item.self) { await collected.append($0) }
        }

        for chunk in chunks {
            pipe.fileHandleForWriting.write(Data(chunk.utf8))
        }
        try? pipe.fileHandleForWriting.close()

        await reading.value
        return await collected.items
    }

    private func line(_ index: Int, body: String = "x") -> String {
        #"{"index":\#(index),"body":"\#(body)"}"# + "\n"
    }

    func testDecodesEveryLineInASingleChunk() async {
        let chunk = (0..<5).map { line($0) }.joined()

        let items = await run(chunks: [chunk])

        XCTAssertEqual(items.map(\.index), [0, 1, 2, 3, 4])
    }

    func testReassemblesALineSplitAcrossChunks() async {
        let whole = line(7, body: "split")
        let cut = whole.index(whole.startIndex, offsetBy: 9)

        let items = await run(chunks: [String(whole[..<cut]), String(whole[cut...])])

        XCTAssertEqual(items, [Item(index: 7, body: "split")])
    }

    func testSplitInsideAMultiByteCharacterSurvives() async {
        // A UTF-8 scalar straddling a chunk boundary used to be corrupted by
        // decoding each chunk to String before buffering.
        let whole = Array(line(1, body: "café ☕️").utf8)
        let cut = whole.firstIndex(of: 0xC3) ?? 0  // first byte of "é"

        let handler = JSONLinesPipeHandler()
        let pipe = await handler.getPipe()
        let collected = Collected()
        let reading = Task {
            await handler.readJSONLines(as: Item.self) { await collected.append($0) }
        }
        pipe.fileHandleForWriting.write(Data(whole[..<(cut + 1)]))
        pipe.fileHandleForWriting.write(Data(whole[(cut + 1)...]))
        try? pipe.fileHandleForWriting.close()
        await reading.value

        let items = await collected.items
        XCTAssertEqual(items, [Item(index: 1, body: "café ☕️")])
    }

    func testTrailingPartialLineIsNotEmittedUntilComplete() async {
        let items = await run(chunks: [line(1), #"{"index":2,"body":"unterminated""#])

        XCTAssertEqual(items.map(\.index), [1], "a line without its newline is still incomplete")
    }

    func testBlankLinesAreSkipped() async {
        let items = await run(chunks: ["\n" + line(3) + "\n\n" + line(4)])

        XCTAssertEqual(items.map(\.index), [3, 4])
    }

    func testUndecodableLineDoesNotStopTheStream() async {
        let items = await run(chunks: [line(1) + "not json\n" + line(2)])

        XCTAssertEqual(items.map(\.index), [1, 2])
    }

    func testHandlesArtworkSizedPayloads() async {
        // The adapter inlines base64 artwork, so a real chunk is hundreds of KiB.
        let big = String(repeating: "A", count: 300_000)

        let items = await run(chunks: [line(1, body: big) + line(2)])

        XCTAssertEqual(items.map(\.index), [1, 2])
        XCTAssertEqual(items.first?.body?.count, big.count)
    }
}
