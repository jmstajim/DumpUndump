import Foundation
import Darwin

final class DefaultFileChangeWatcher: FileChangeWatcher {
    private var dirSource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var reopenTimer: DispatchSourceTimer?
    private var dirFD: CInt = -1
    private var fileFD: CInt = -1
    private var onChange: (() -> Void)?
    private var watchedURL: URL?
    private var watchedName: String = ""
    private var debounceWork: DispatchWorkItem?
    private let debounce: TimeInterval
    private var dirAccessed = false
    private var fileAccessed = false
    private var lastSig: Signature?
    
    private struct Signature: Equatable {
        let dev: UInt64
        let ino: UInt64
        let size: Int64
        let mtSec: Int64
        let mtNsec: Int64
    }
    
    init(debounce: TimeInterval = 0.2) {
        self.debounce = debounce
    }
    
    func start(url: URL, onChange: @escaping () -> Void) {
        stop()
        self.onChange = onChange
        self.watchedURL = url
        self.watchedName = url.lastPathComponent
        armDirectoryWatcher(at: url.deletingLastPathComponent())
        armFileWatcher(at: url)
        lastSig = statSignature(path: url.path)
    }
    
    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        reopenTimer?.cancel()
        reopenTimer = nil
        if let s = fileSource { s.cancel() }
        fileSource = nil
        if let s = dirSource { s.cancel() }
        dirSource = nil
        if fileFD >= 0 { close(fileFD) }
        if dirFD >= 0 { close(dirFD) }
        fileFD = -1
        dirFD = -1
        if fileAccessed, let u = watchedURL { u.stopAccessingSecurityScopedResource() }
        if dirAccessed, let du = watchedURL?.deletingLastPathComponent() { du.stopAccessingSecurityScopedResource() }
        fileAccessed = false
        dirAccessed = false
        lastSig = nil
        onChange = nil
        watchedURL = nil
        watchedName = ""
    }
    
    private func armDirectoryWatcher(at dirURL: URL) {
        if !dirAccessed { dirAccessed = dirURL.startAccessingSecurityScopedResource() }
        dirFD = open(dirURL.path, O_EVTONLY)
        guard dirFD >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: dirFD, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            self.schedule()
            self.ensureReattached()
        }
        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.dirFD >= 0 { close(self.dirFD) }
            self.dirFD = -1
        }
        dirSource = src
        src.resume()
    }
    
    private func armFileWatcher(at url: URL) {
        if !fileAccessed { fileAccessed = url.startAccessingSecurityScopedResource() }
        fileFD = open(url.path, O_EVTONLY)
        guard fileFD >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileFD, eventMask: [.write, .extend, .attrib, .rename, .delete, .link], queue: .main)
        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            let events = DispatchSource.FileSystemEvent(rawValue: src.data)
            self.schedule()
            if events.contains(.rename) || events.contains(.delete) || events.contains(.link) {
                self.detachFileWatcher()
                self.beginReopenLoop()
            }
        }
        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileFD >= 0 { close(self.fileFD) }
            self.fileFD = -1
        }
        fileSource = src
        src.resume()
    }
    
    private func detachFileWatcher() {
        if let s = fileSource { s.cancel() }
        fileSource = nil
        if fileFD >= 0 { close(fileFD) }
        fileFD = -1
    }
    
    private func schedule() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let newSig = self.statSignature(path: self.currentPath())
            if self.lastSig != newSig {
                self.lastSig = newSig
                self.onChange?()
            }
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }
    
    private func ensureReattached() {
        if fileSource == nil || fileFD < 0 {
            beginReopenLoop()
        } else {
            schedule()
        }
    }
    
    private func beginReopenLoop() {
        if reopenTimer != nil { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let path = self.currentPath()
            if access(path, F_OK) == 0 {
                if let url = self.watchedURL {
                    self.armFileWatcher(at: url)
                    self.schedule()
                    self.reopenTimer?.cancel()
                    self.reopenTimer = nil
                }
            }
        }
        reopenTimer = timer
        timer.resume()
    }
    
    private func currentPath() -> String {
        if let u = watchedURL { return u.deletingLastPathComponent().appendingPathComponent(watchedName).path }
        return ""
    }
    
    private func statSignature(path: String) -> Signature? {
        var st = stat()
        if stat(path, &st) == 0 {
            return Signature(dev: UInt64(st.st_dev), ino: UInt64(st.st_ino), size: Int64(st.st_size), mtSec: Int64(st.st_mtimespec.tv_sec), mtNsec: Int64(st.st_mtimespec.tv_nsec))
        }
        return nil
    }
}
