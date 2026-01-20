import XCTest
@testable import DumpUndump

final class UnifiedDiffParserTests: XCTestCase {

    func test_parse_singleFile_replaceLine_ok() throws {
        let expectedPath = "README.md"
        let diff = UnifiedDiffSamples.replaceLine_readme_gitHeader

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        XCTAssertEqual(patch.expectedPath, expectedPath)
        XCTAssertEqual(patch.hunks.count, 1)
        XCTAssertEqual(patch.isNewFile, false)
        XCTAssertEqual(patch.isDelete, false)
    }

    func test_parse_newFile_ok() throws {
        let expectedPath = "NewFile.txt"
        let diff = UnifiedDiffSamples.newFile_viaDevNull

        let patch = try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)
        XCTAssertEqual(patch.expectedPath, expectedPath)
        XCTAssertTrue(patch.isNewFile)
        XCTAssertEqual(patch.isDelete, false)
        XCTAssertEqual(patch.hunks.count, 1)
    }

    func test_parse_multiFile_rejected() throws {
        let expectedPath = "file1.txt"
        let diff = UnifiedDiffSamples.multiFile_patch_twoDiffGit

        XCTAssertThrowsError(try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)) { err in
            XCTAssertEqual(err as? UnifiedDiffParseError, .multiFileNotAllowed)
        }
    }

    func test_parse_binaryFilesDiffer_rejected() throws {
        let expectedPath = "image.png"
        let diff = UnifiedDiffSamples.binary_filesDiffer

        XCTAssertThrowsError(try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)) { err in
            XCTAssertEqual(err as? UnifiedDiffParseError, .binaryNotSupported)
        }
    }

    func test_parse_gitBinaryPatch_rejected() throws {
        let expectedPath = "image.png"
        let diff = UnifiedDiffSamples.gitBinaryPatch

        XCTAssertThrowsError(try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)) { err in
            XCTAssertEqual(err as? UnifiedDiffParseError, .gitBinaryPatchNotSupported)
        }
    }

    func test_parse_deleteViaDiff_rejected() throws {
        let expectedPath = "deleted.txt"
        let diff = UnifiedDiffSamples.delete_viaDevNull

        XCTAssertThrowsError(try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)) { err in
            XCTAssertEqual(err as? UnifiedDiffParseError, .deleteNotSupported)
        }
    }

    func test_parse_missingHunks_rejected() throws {
        let expectedPath = "README.md"
        let diff = """
        --- a/README.md
        +++ b/README.md
        """

        XCTAssertThrowsError(try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)) { err in
            XCTAssertEqual(err as? UnifiedDiffParseError, .missingHunks)
        }
    }

    func test_parse_pathMismatch_rejected() throws {
        let expectedPath = "Expected.txt"
        let diff = """
        --- a/Other.txt
        +++ b/Other.txt
        @@ -1,1 +1,1 @@
        -a
        +b
        """

        XCTAssertThrowsError(try UnifiedDiffParser.parseSingleFilePatch(diff, expectedPath: expectedPath)) { err in
            guard case let .pathMismatch(expected, got)? = err as? UnifiedDiffParseError else {
                return XCTFail("Expected pathMismatch, got: \(err)")
            }
            XCTAssertEqual(expected, expectedPath)
            XCTAssertEqual(got, "Other.txt")
        }
    }
}
