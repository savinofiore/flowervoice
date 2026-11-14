import Foundation

/// Files only the current user may read: directories 0700, files 0600, never briefly world-readable.
enum PrivateFiles {
    private static let FILE_PERMISSIONS: Int16 = 0o600
    private static let DIRECTORY_PERMISSIONS: Int16 = 0o700

    /// Writes atomically: the temporary file is created 0600 before any byte is written, then renamed over the target.
    static func write(_ data: Data, to url: URL) throws {
        let temporary = url.deletingLastPathComponent().appending(path: ".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try createExclusively(temporary, contents: data)
        guard rename(temporary.path, url.path) == 0 else {
            try? FileManager.default.removeItem(at: temporary)
            throw CocoaError(.fileWriteUnknown)
        }
    }

    /// Appends to the file, creating it 0600 if missing.
    static func append(_ data: Data, to url: URL) throws {
        guard let handle = FileHandle(forWritingAtPath: url.path) else { return try write(data, to: url) }
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    static func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: DIRECTORY_PERMISSIONS]
        )
    }

    /// Tightens permissions of files written by older versions (0644 / 0755).
    static func restrictExisting(directory: URL, files: [URL]) {
        let manager = FileManager.default
        try? manager.setAttributes([.posixPermissions: DIRECTORY_PERMISSIONS], ofItemAtPath: directory.path)
        files.forEach { try? manager.setAttributes(fileAttributes, ofItemAtPath: $0.path) }
    }

    private static func createExclusively(_ url: URL, contents: Data) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(FILE_PERMISSIONS))
        guard descriptor >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: contents)
            try handle.close()
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private static var fileAttributes: [FileAttributeKey: Any] {
        [.posixPermissions: FILE_PERMISSIONS]
    }
}
