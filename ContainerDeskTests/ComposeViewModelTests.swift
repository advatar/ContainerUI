import XCTest
@testable import ContainerDesk

final class ComposeViewModelTests: XCTestCase {
    func testComposeCommandArgumentsIncludeFileAndProject() {
        let args = ComposeViewModel.composeCommandArguments(
            composeFile: "stack/compose.yaml",
            projectName: "demo",
            subcommand: ["up", "-d"]
        )

        XCTAssertEqual(args, ["compose", "-f", "stack/compose.yaml", "-p", "demo", "up", "-d"])
    }

    func testComposeCommandArgumentsOmitEmptyFlags() {
        let args = ComposeViewModel.composeCommandArguments(
            composeFile: "  ",
            projectName: "",
            subcommand: ["ps", "--all"]
        )

        XCTAssertEqual(args, ["compose", "ps", "--all"])
    }
}
