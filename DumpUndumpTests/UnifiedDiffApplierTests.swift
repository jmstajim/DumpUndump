import XCTest
@testable import DumpUndump

final class UnifiedDiffApplierTests: XCTestCase {

    func test_apply_replaceLine_ok() throws {
        let expectedPath = "README.md"
        let diff = UnifiedDiffSamples.replaceLine_readme_minHeader

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        let oldText = "Hello\nLine 2\nLine 3\n"
        let newText = try UnifiedDiffApplier.apply(patch: patch, to: oldText)

        XCTAssertEqual(newText, "Hello, world!\nLine 2\nLine 3\n")
    }

    func test_apply_insertLine_ok() throws {
        let expectedPath = "notes.txt"
        let diff = UnifiedDiffSamples.insert_oneLine

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        let oldText = "A\nB\nC\n"
        let newText = try UnifiedDiffApplier.apply(patch: patch, to: oldText)

        XCTAssertEqual(newText, "A\nB\nB2\nC\n")
    }

    func test_apply_deleteLine_ok() throws {
        let expectedPath = "notes.txt"
        let diff = UnifiedDiffSamples.delete_oneLine

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        let oldText = "A\nB\nC\n"
        let newText = try UnifiedDiffApplier.apply(patch: patch, to: oldText)

        XCTAssertEqual(newText, "A\nC\n")
    }

    func test_apply_replaceLine_removePlusAdd_ok() throws {
        let expectedPath = "notes.txt"
        let diff = UnifiedDiffSamples.replace_removePlusAdd

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        let oldText = "A\nB\nC\n"
        let newText = try UnifiedDiffApplier.apply(patch: patch, to: oldText)

        XCTAssertEqual(newText, "A\nB_REPLACED\nC\n")
    }

    func test_apply_multipleHunks_ok() throws {
        let expectedPath = "multi.txt"
        let diff = UnifiedDiffSamples.multiple_hunks

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        let oldText = "L1\nL2\nL3\nL4\nL5\n"
        let newText = try UnifiedDiffApplier.apply(patch: patch, to: oldText)

        XCTAssertEqual(newText, "L1\nL2_changed\nL3\nL4\nL5\nL5_added\n")
    }

    func test_apply_contextMismatch_throws() throws {
        let expectedPath = "README.md"
        let diff = UnifiedDiffSamples.replaceLine_readme_minHeader

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        let oldText = "HELLO\nLine 2\nLine 3\n"

        XCTAssertThrowsError(try UnifiedDiffApplier.apply(patch: patch, to: oldText)) { err in
            XCTAssertNotNil(err as? UnifiedDiffApplyError)
            XCTAssertEqual(err as? UnifiedDiffApplyError,
                           .contextMismatch(expected: "Hello", actual: "HELLO", lineIndex: 0))
        }
    }
}
