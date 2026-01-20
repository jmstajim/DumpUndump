import Foundation

enum UnifiedDiffSamples {

    // MARK: - Parser happy paths

    static let replaceLine_readme_gitHeader = """
    diff --git a/README.md b/README.md
    index 1111111..2222222 100644
    --- a/README.md
    +++ b/README.md
    @@ -1,3 +1,3 @@
    -Hello
    +Hello, world!
     Line 2
     Line 3
    """

    static let replaceLine_readme_minHeader = """
    --- a/README.md
    +++ b/README.md
    @@ -1,3 +1,3 @@
    -Hello
    +Hello, world!
     Line 2
     Line 3
    """

    static let newFile_viaDevNull = """
    diff --git a/NewFile.txt b/NewFile.txt
    new file mode 100644
    --- /dev/null
    +++ b/NewFile.txt
    @@ -0,0 +1,3 @@
    +Line 1
    +Line 2
    +Line 3
    """

    // MARK: - Parser rejects

    static let multiFile_patch_twoDiffGit = """
    diff --git a/file1.txt b/file1.txt
    --- a/file1.txt
    +++ b/file1.txt
    @@ -1 +1 @@
    -a
    +b
    diff --git a/file2.txt b/file2.txt
    --- a/file2.txt
    +++ b/file2.txt
    @@ -1 +1 @@
    -x
    +y
    """

    static let binary_filesDiffer = """
    diff --git a/image.png b/image.png
    index 1111111..2222222 100644
    Binary files a/image.png and b/image.png differ
    """

    static let gitBinaryPatch = """
    diff --git a/image.png b/image.png
    index 1111111..2222222 100644
    GIT binary patch
    literal 0
    HcmV?d00001
    """

    static let delete_viaDevNull = """
    diff --git a/deleted.txt b/deleted.txt
    deleted file mode 100644
    --- a/deleted.txt
    +++ /dev/null
    @@ -1,1 +0,0 @@
    -gone
    """

    // MARK: - Applier happy paths

    static let insert_oneLine = """
    --- a/notes.txt
    +++ b/notes.txt
    @@ -1,3 +1,4 @@
     A
     B
    +B2
     C
    """

    static let delete_oneLine = """
    --- a/notes.txt
    +++ b/notes.txt
    @@ -1,3 +1,2 @@
     A
    -B
     C
    """

    static let replace_removePlusAdd = """
    --- a/notes.txt
    +++ b/notes.txt
    @@ -1,3 +1,3 @@
     A
    -B
    +B_REPLACED
     C
    """

    static let multiple_hunks = """
    --- a/multi.txt
    +++ b/multi.txt
    @@ -1,3 +1,3 @@
     L1
    -L2
    +L2_changed
     L3
    @@ -4,2 +4,3 @@
     L4
     L5
    +L5_added
    """
}
