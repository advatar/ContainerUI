import XCTest
@testable import ContainerDesk

final class CommandCenterViewModelTests: XCTestCase {
    func testNormalizedArgumentsStripsDockerPrefix() throws {
        let args = try CommandCenterViewModel.normalizedArguments(from: "docker ps --all")
        XCTAssertEqual(args, ["ps", "--all"])
    }

    func testNormalizedArgumentsPreservesQuotedSegments() throws {
        let args = try CommandCenterViewModel.normalizedArguments(
            from: "docker run --name \"my app\" -e FOO='bar baz' nginx:latest"
        )
        XCTAssertEqual(args, ["run", "--name", "my app", "-e", "FOO=bar baz", "nginx:latest"])
    }

    func testNormalizedArgumentsRejectsEmptyCommand() {
        XCTAssertThrowsError(try CommandCenterViewModel.normalizedArguments(from: "   "))
    }

    @MainActor
    func testCatalogContainsCoreDockerCommands() {
        let names = Set(DockerCommandCatalog.sections.flatMap { section in
            section.commands.map(\.name)
        })

        XCTAssertTrue(names.contains("run"))
        XCTAssertTrue(names.contains("compose"))
        XCTAssertTrue(names.contains("network"))
        XCTAssertTrue(names.contains("volume"))
        XCTAssertTrue(names.contains("swarm"))
    }
}
