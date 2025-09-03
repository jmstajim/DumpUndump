import Foundation

final class DefaultFileChangeWatcher: FileChangeWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fd: CInt = -1
    private var isAccessing = false
    private var work: DispatchWorkItem?
    private let debounce: TimeInterval

    init(debounce: TimeInterval = 0.2) {
        self.debounce = debounce
    }

    func start(url: URL, onChange: @escaping () -> Void) {
        stop()
        isAccessing = url.startAccessingSecurityScopedResource()
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
            isAccessing = false
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            self.work?.cancel()
            let w = DispatchWorkItem { onChange() }
            self.work = w
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounce, execute: w)
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

