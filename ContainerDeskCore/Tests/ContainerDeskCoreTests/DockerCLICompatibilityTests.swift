import Foundation
import XCTest
@testable import ContainerDeskCore

final class DockerCLICompatibilityTests: XCTestCase {

    func testContainerFirstMappingsForRepresentativeDockerCommands() async throws {
        let harness = try FakeContainerHarness()
        defer { harness.cleanup() }

        let engine = harness.makeEngine()
        let mappings: [([String], [String])] = [
            (["ps", "--all"], ["list", "--all"]),
            (["images"], ["image", "list"]),
            (["rm", "abc123"], ["delete", "abc123"]),
            (["rmi", "nginx:latest"], ["image", "delete", "nginx:latest"]),
            (["container", "ls", "-a"], ["list", "-a"]),
            (["container", "rm", "abc123"], ["delete", "abc123"]),
            (["image", "ls"], ["image", "list"]),
            (["system", "status"], ["system", "status"]),
            (["buildx", "ls"], ["builder", "status"]),
            (["compose", "ps"], ["compose", "ps"]),
            (["network", "ls"], ["network", "ls"]),
        ]

        for (requested, expected) in mappings {
            let result = try await engine.runDockerCompatibleCommand(
                requested,
                environment: harness.environment(mode: "first_candidate_success")
            )

            XCTAssertEqual(result.arguments, expected, "Requested \(requested) mapped to unexpected command \(result.arguments).")
            XCTAssertEqual(result.exitCode, 0)
        }

        let invocations = try harness.invocations()
        XCTAssertEqual(invocations.count, mappings.count)

        for (index, mapping) in mappings.enumerated() {
            XCTAssertEqual(invocations[index], mapping.1, "Invocation order mismatch at index \(index).")
        }
    }

    func testFallbackOnUnknownCommandUsesNextCandidate() async throws {
        let harness = try FakeContainerHarness()
        defer { harness.cleanup() }

        let engine = harness.makeEngine()
        let result = try await engine.runDockerCompatibleCommand(
            ["ps", "--all"],
            environment: harness.environment(mode: "ps_fallback")
        )

        XCTAssertEqual(result.arguments, ["ls", "--all"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("\"ID\":\"abc123\""))

        let invocations = try harness.invocations()
        XCTAssertEqual(invocations, [["list", "--all"], ["ls", "--all"]])
    }

    func testComposeFallbackUsesSystemComposeWhenDirectComposeIsUnavailable() async throws {
        let harness = try FakeContainerHarness()
        defer { harness.cleanup() }

        let engine = harness.makeEngine()
        let result = try await engine.runDockerCompatibleCommand(
            ["compose", "ps"],
            environment: harness.environment(mode: "compose_fallback")
        )

        XCTAssertEqual(result.arguments, ["system", "compose", "ps"])
        XCTAssertEqual(result.exitCode, 0)

        let invocations = try harness.invocations()
        XCTAssertEqual(invocations, [["compose", "ps"], ["system", "compose", "ps"]])
    }

    func testNonCompatibilityFailureDoesNotFallbackWhenCheckExitCodeIsEnabled() async throws {
        let harness = try FakeContainerHarness()
        defer { harness.cleanup() }

        let engine = harness.makeEngine()

        do {
            _ = try await engine.runDockerCompatibleCommand(
                ["ps", "--all"],
                environment: harness.environment(mode: "non_compat_failure")
            )
            XCTFail("Expected command failure.")
        } catch let error as ProcessRunnerError {
            guard case let .commandFailed(_, arguments, exitCode, stderr) = error else {
                XCTFail("Expected commandFailed error, received: \(error).")
                return
            }

            XCTAssertEqual(arguments, ["list", "--all"])
            XCTAssertEqual(exitCode, 1)
            XCTAssertTrue(stderr.contains("permission denied"))
        } catch {
            XCTFail("Unexpected error type: \(error).")
        }

        let invocations = try harness.invocations()
        XCTAssertEqual(invocations, [["list", "--all"]])
    }
}

private struct FakeContainerHarness {
    let rootURL: URL
    let scriptURL: URL
    let logURL: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContainerDeskCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        self.rootURL = root
        self.scriptURL = root.appendingPathComponent("fake-container.sh")
        self.logURL = root.appendingPathComponent("invocations.log")

        try Self.writeScript(to: scriptURL)
    }

    func makeEngine() -> ContainerEngine {
        ContainerEngine(containerPath: scriptURL.path)
    }

    func environment(mode: String) -> [String: String] {
        [
            "FAKE_MODE": mode,
            "FAKE_LOG": logURL.path
        ]
    }

    func invocations() throws -> [[String]] {
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            return []
        }

        let content = try String(contentsOf: logURL, encoding: .utf8)
        return content
            .split(whereSeparator: \.isNewline)
            .map { line in
                line
                    .split(separator: "\u{1F}", omittingEmptySubsequences: true)
                    .map(String.init)
            }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private static func writeScript(to url: URL) throws {
        let script = """
        #!/bin/sh

        if [ -n "${FAKE_LOG:-}" ]; then
          {
            for arg in "$@"; do
              printf '%s\\037' "$arg"
            done
            printf '\\n'
          } >> "$FAKE_LOG"
        fi

        mode="${FAKE_MODE:-}"
        arg1="${1:-}"
        arg2="${2:-}"

        case "$mode" in
          first_candidate_success)
            printf 'ok:%s\\n' "$*"
            exit 0
            ;;
          ps_fallback)
            if [ "$arg1" = "list" ]; then
              echo 'unknown command "list"' 1>&2
              exit 125
            fi
            if [ "$arg1" = "ls" ]; then
              echo '{"ID":"abc123","Name":"web","Image":"nginx:latest","Status":"Running"}'
              exit 0
            fi
            ;;
          compose_fallback)
            if [ "$arg1" = "compose" ]; then
              echo 'unknown command "compose"' 1>&2
              exit 125
            fi
            if [ "$arg1" = "system" ] && [ "$arg2" = "compose" ]; then
              echo 'web running'
              exit 0
            fi
            ;;
          non_compat_failure)
            if [ "$arg1" = "list" ]; then
              echo 'permission denied' 1>&2
              exit 1
            fi
            ;;
        esac

        echo "unsupported: $*" 1>&2
        exit 127
        """

        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
