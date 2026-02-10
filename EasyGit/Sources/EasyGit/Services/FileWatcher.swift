import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private let path: String
    private let callback: () -> Void
    private var debounceWorkItem: DispatchWorkItem?

    init(path: String, callback: @escaping () -> Void) {
        self.path = path
        self.callback = callback
    }

    func start() {
        stop()

        dirFD = open(path, O_EVTONLY)
        guard dirFD >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .global(qos: .utility)
        )

        source?.setEventHandler { [weak self] in
            self?.debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.callback()
            }
            self?.debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.dirFD, fd >= 0 {
                close(fd)
                self?.dirFD = -1
            }
        }

        source?.resume()
    }

    func stop() {
        debounceWorkItem?.cancel()
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
