import AppKit
import Foundation

final class AsyncPasteboardTextWriter: @unchecked Sendable {
    typealias WriteOperation = @Sendable (String) -> Bool

    private let queue: DispatchQueue
    private let writeOperation: WriteOperation

    init(
        queue: DispatchQueue = DispatchQueue(
            label: "typeflux.clipboard.write",
            qos: .userInitiated
        ),
        writeOperation: @escaping WriteOperation = { text in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.setString(text, forType: .string)
        }
    ) {
        self.queue = queue
        self.writeOperation = writeOperation
    }

    func write(
        _ text: String,
        completion: @MainActor @escaping @Sendable (Bool) -> Void
    ) {
        queue.async { [writeOperation] in
            let didWrite = writeOperation(text)
            Task { @MainActor in
                completion(didWrite)
            }
        }
    }
}
