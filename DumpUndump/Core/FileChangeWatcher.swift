import Foundation

final class DefaultFileChangeWatcher: FileChangeWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fd: CInt = -1
    private var isAccessing = false
    private var work: DispatchWorkItem?
    private let debounce: TimeInterval

    private var watchedURL: URL?
    private var onChange: (() -> Void)?
    private var isRestartScheduled: Bool = false

    init(debounce: TimeInterval = 0.2) {
        self.debounce = debounce
    }

    func start(url: URL, onChange: @escaping () -> Void) {
        stop()
        self.watchedURL = url
        self.onChange = onChange
        setupSource(for: url)
    }

    private func setupSource(for url: URL) {
        isAccessing = url.startAccessingSecurityScopedResource()
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
            isAccessing = false
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let events = DispatchSource.FileSystemEvent(rawValue: src.data)
            self.work?.cancel()
            let w = DispatchWorkItem { [weak self] in self?.onChange?() }
            self.work = w
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounce, execute: w)

            if events.contains(.rename) || events.contains(.delete) {
                self.restartAfterDelay()
            }
        }
        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fd >= 0 { close(self.fd) }
            self.fd = -1
            if self.isAccessing { url.stopAccessingSecurityScopedResource() }
            self.isAccessing = false
        }
        source = src
        src.resume()
    }

    private func restartAfterDelay() {
        guard !isRestartScheduled else { return }
        isRestartScheduled = true
        let delay = max(debounce, 0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.isRestartScheduled = false
            let url = self.watchedURL
            let cb = self.onChange
            self.stop()
            if let url, let cb {
                self.start(url: url, onChange: cb)
            }
        }
    }

    func stop() {
        work?.cancel()
        work = nil
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
