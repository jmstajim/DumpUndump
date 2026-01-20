import XCTest
@testable import DumpUndump

final class UndumpIntegration_UdiffTests: XCTestCase {

    func test_undump_unifiedDiff_updatesExistingFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("README.md")
        try "Hello\nLine 2\nLine 3\n".data(using: .utf8)!.write(to: fileURL)

        let undumpText = """
        <<<FILE #1>>>
        PATH: README.md
        ```diff
        --- a/README.md
        +++ b/README.md
        @@ -1,3 +1,3 @@
        -Hello
        +Hello, world!
         Line 2
         Line 3
        ```
        <<<END FILE #1>>>
        """

        let report = try Undump.undump(text: undumpText, toRoot: root, dryRun: false, makeBackups: false)
        XCTAssertEqual(report.updated, ["README.md"])
        XCTAssertEqual(report.failed, [])

        let newText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(newText, "Hello, world!\nLine 2\nLine 3\n")
    }

    func test_undump_unifiedDiff_createsNewFile_viaDevNull() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: root) }

        let undumpText = """
        <<<FILE #1>>>
        PATH: NewFile.txt
        ```diff
        --- /dev/null
        +++ b/NewFile.txt
        @@ -0,0 +1,2 @@
        +Line 1
        +Line 2
        ```
        <<<END FILE #1>>>
        """

        let report = try Undump.undump(text: undumpText, toRoot: root, dryRun: false, makeBackups: false)
        XCTAssertEqual(report.created, ["NewFile.txt"])
        XCTAssertEqual(report.failed, [])

        let fileURL = root.appendingPathComponent("NewFile.txt")
        let newText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(newText, "Line 1\nLine 2\n")
    }
}
