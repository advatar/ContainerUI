import XCTest
@testable import ContainerDesk

@MainActor
final class ContainerDeskUITests: XCTestCase {
    func testSidebarNavigationMatchesDesktopStructure() {
        let allCases = NavItem.allCases
        let expectedCases: [NavItem] = [.dashboard, .containers, .images, .builds, .compose, .dockerCLI, .troubleshoot, .settings]
        XCTAssertEqual(allCases, expectedCases)

        let names = allCases.map { item in
            item.rawValue
        }
        XCTAssertEqual(names, ["Dashboard", "Containers", "Images", "Builds", "Compose", "Docker CLI", "Troubleshoot", "Settings"])
    }

    func testSidebarNavigationUsesStableIdentifiersAndSymbols() {
        for item in NavItem.allCases {
            let itemID = item.id
            XCTAssertEqual(itemID, item.rawValue)

            let symbolName = item.systemImage
            XCTAssertFalse(symbolName.isEmpty)
        }
    }

    func testCommandCenterUsesDocumentedDockerSections() {
        let sectionTitles = DockerCommandCatalog.sections.map { section in
            section.title
        }
        XCTAssertEqual(sectionTitles, ["Common", "Management", "Compose", "Swarm", "Runtime"])
    }

    func testCommandCenterIncludesCoreDockerDesktopCommands() {
        var commands = Set<String>()
        for section in DockerCommandCatalog.sections {
            for command in section.commands {
                commands.insert(command.name)
            }
        }

        let expected = [
            "run", "exec", "ps", "build", "pull", "push", "images", "login", "logout", "search", "version", "info",
            "compose", "container", "context", "image", "network", "system", "volume",
            "compose up", "compose down", "compose ps", "compose logs",
            "config", "node", "secret", "service", "stack", "swarm",
            "logs", "stats", "top", "events", "inspect"
        ]

        for command in expected {
            XCTAssertTrue(commands.contains(command), "Missing Docker command: \(command)")
        }
    }
}
