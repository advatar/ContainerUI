import XCTest
@testable import ContainerDeskCore

final class ContainerDeskCoreTests: XCTestCase {

    func testJSONValueDecodesNested() throws {
        let json = """
        {
          "a": "hello",
          "b": 123,
          "c": true,
          "d": null,
          "e": [1, 2, 3],
          "f": {"x": "y"}
        }
        """
        let data = Data(json.utf8)
        let obj = try JSONDecoder().decode([String: JSONValue].self, from: data)
        XCTAssertEqual(obj["a"]?.stringValue, "hello")
        XCTAssertEqual(obj["b"]?.stringValue, "123")
        XCTAssertEqual(obj["c"]?.boolValue, true)
        XCTAssertNil(obj["d"]?.stringValue)
        XCTAssertEqual(obj["e"]?.arrayValue?.count, 3)
        XCTAssertEqual(obj["f"]?.objectValue?["x"]?.stringValue, "y")
    }

    func testContainerSummaryHeuristics() throws {
        let raw: [String: JSONValue] = [
            "ID": .string("abc123"),
            "Name": .string("web"),
            "Image": .string("nginx:latest"),
            "Status": .string("Running"),
            "Ports": .string("127.0.0.1:8080->80/tcp")
        ]
        let c = ContainerSummary(raw: raw)
        XCTAssertEqual(c.id, "abc123")
        XCTAssertEqual(c.name, "web")
        XCTAssertEqual(c.image, "nginx:latest")
        XCTAssertEqual(c.state, .running)
        XCTAssertNotNil(c.ports)
    }

    func testImageSummaryHeuristics() throws {
        let raw: [String: JSONValue] = [
            "Repository": .string("nginx"),
            "Tag": .string("latest"),
            "ID": .string("sha256:deadbeef"),
            "Size": .string("100MB")
        ]
        let img = ImageSummary(raw: raw)
        XCTAssertEqual(img.reference, "nginx:latest")
        XCTAssertEqual(img.size, "100MB")
    }

    func testCommandLineTokenizerSupportsQuotesAndEscapes() throws {
        let tokens = try CommandLineTokenizer.tokenize("docker run --name \"my app\" -e FOO='bar baz' nginx:latest")
        XCTAssertEqual(tokens, ["docker", "run", "--name", "my app", "-e", "FOO=bar baz", "nginx:latest"])
    }

    func testCommandLineTokenizerThrowsOnUnterminatedQuote() {
        XCTAssertThrowsError(try CommandLineTokenizer.tokenize("docker run \"oops")) { error in
            guard case CommandLineTokenizerError.unterminatedQuote = error else {
                XCTFail("Expected unterminatedQuote error.")
                return
            }
        }
    }
}
