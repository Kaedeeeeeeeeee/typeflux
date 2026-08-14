import ApplicationServices
import Foundation

extension AXTextInjector {
    struct AXValueReplacement: Equatable {
        let text: String
        let caretLocation: Int
    }

    static let unicodeEventChunkUTF16Limit = 64

    static func replacingAXValue(
        _ originalText: String,
        selectedRange: CFRange,
        with replacementText: String
    ) -> AXValueReplacement? {
        guard selectedRange.location >= 0, selectedRange.length >= 0 else { return nil }

        let originalLength = (originalText as NSString).length
        guard selectedRange.location <= originalLength else { return nil }
        guard selectedRange.length <= originalLength - selectedRange.location else { return nil }

        let replacementRange = NSRange(
            location: selectedRange.location,
            length: selectedRange.length
        )
        let updatedText = (originalText as NSString).replacingCharacters(
            in: replacementRange,
            with: replacementText
        )
        return AXValueReplacement(
            text: updatedText,
            caretLocation: selectedRange.location + (replacementText as NSString).length
        )
    }

    static func unicodeEventChunks(
        for text: String,
        maximumUTF16Length: Int = unicodeEventChunkUTF16Limit
    ) -> [String] {
        guard !text.isEmpty, maximumUTF16Length > 0 else { return [] }

        var chunks: [String] = []
        var currentChunk = ""
        var currentUTF16Length = 0

        for character in text {
            let value = String(character)
            let valueLength = value.utf16.count
            if !currentChunk.isEmpty, currentUTF16Length + valueLength > maximumUTF16Length {
                chunks.append(currentChunk)
                currentChunk = ""
                currentUTF16Length = 0
            }

            currentChunk.append(value)
            currentUTF16Length += valueLength
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        return chunks
    }

    static func canUseVerifiedUnicodeInput(
        snapshot: CurrentInputTextSnapshot,
        targetProcessID: pid_t?
    ) -> Bool {
        guard snapshot.isEditable, snapshot.isFocusedTarget else { return false }
        guard snapshot.textSource == "ax-value", snapshot.text != nil else { return false }
        guard snapshot.selectedRange != nil else { return false }
        guard let targetProcessID, let snapshotProcessID = snapshot.processID else { return false }
        return targetProcessID == snapshotProcessID
    }

    static func evaluateDirectInputVerification(
        targetProcessID: pid_t?,
        before: CurrentInputTextSnapshot,
        after: CurrentInputTextSnapshot
    ) -> PasteVerificationResult {
        if let targetProcessID, let afterProcessID = after.processID,
           targetProcessID != afterProcessID {
            return .failure("focused-process-changed")
        }

        if let reason = after.failureReason,
           reason == "accessibility-not-trusted" || reason == "no-focused-element" {
            return .failure(reason)
        }

        guard let beforeText = before.text, let afterText = after.text else {
            return .indeterminate
        }
        guard after.isEditable, after.isFocusedTarget else {
            return .indeterminate
        }
        return beforeText == afterText ? .failure("input-text-unchanged") : .success
    }

    func insertTextViaWritableAXValue(
        _ text: String,
        into element: AXUIElement,
        selectionRange: CFRange?
    ) throws -> Bool {
        var elementProcessID: pid_t = 0
        guard AXUIElementGetPid(element, &elementProcessID) == .success else { return false }
        guard frontmostProcessID() == elementProcessID else { return false }

        let role = copyStringAttribute(kAXRoleAttribute as String, from: element)
        guard Self.nativeEditableRoles.contains(role ?? "") else { return false }
        guard isAttributeSettable(kAXValueAttribute as CFString, on: element) else { return false }
        guard let currentText = copyTextAttribute(kAXValueAttribute as String, from: element) else {
            return false
        }
        guard let range = selectionRange ?? copySelectedTextRange(from: element) else { return false }
        guard let replacement = Self.replacingAXValue(
            currentText,
            selectedRange: range,
            with: text
        ) else { return false }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            replacement.text as CFTypeRef
        )
        guard result == .success else { return false }

        _ = setSelectedTextRange(
            CFRange(location: replacement.caretLocation, length: 0),
            on: element
        )

        var lastReadback: String?
        for attempt in 0 ..< Self.axWriteVerificationAttempts {
            if attempt > 0 {
                usleep(Self.axWriteVerificationPollIntervalMicroseconds)
            }
            lastReadback = copyTextAttribute(kAXValueAttribute as String, from: element)
            if lastReadback == replacement.text {
                NetworkDebugLogger.logMessage(
                    "[Text Injection] completed via writable AX value"
                )
                return true
            }
        }

        if lastReadback == currentText {
            return false
        }

        throw NSError(
            domain: "AXTextInjector",
            code: 12,
            userInfo: [
                NSLocalizedDescriptionKey: "Accessibility text write produced an unverified value."
            ]
        )
    }

    func insertTextViaUnicodeEvents(
        _ text: String,
        targetProcessID: pid_t?,
        beforeSnapshot: CurrentInputTextSnapshot
    ) throws -> Bool {
        guard Self.canUseVerifiedUnicodeInput(
            snapshot: beforeSnapshot,
            targetProcessID: targetProcessID
        ) else { return false }
        guard postUnicodeText(text, to: targetProcessID) else { return false }

        var sawUnchangedValue = false
        for attempt in 0 ..< Self.axWriteVerificationAttempts {
            usleep(Self.axWriteVerificationPollIntervalMicroseconds)
            let afterSnapshot = readCurrentInputTextSnapshot()
            let verification = Self.evaluateDirectInputVerification(
                targetProcessID: targetProcessID,
                before: beforeSnapshot,
                after: afterSnapshot
            )
            NetworkDebugLogger.logMessage(
                """
                [Text Injection] Unicode event verification attempt \(attempt + 1)
                result: \(String(describing: verification))
                beforeSnapshot: \(snapshotSummary(beforeSnapshot))
                afterSnapshot: \(snapshotSummary(afterSnapshot))
                """
            )

            switch verification {
            case .success:
                NetworkDebugLogger.logMessage(
                    "[Text Injection] completed via Unicode keyboard events"
                )
                return true
            case let .failure(reason):
                if reason == "input-text-unchanged" {
                    sawUnchangedValue = true
                    continue
                }
                throw directInputVerificationError(reason: reason)
            case .indeterminate:
                throw directInputVerificationError(reason: "readback-became-unavailable")
            }
        }

        return !sawUnchangedValue
    }

    private func postUnicodeText(_ text: String, to targetProcessID: pid_t?) -> Bool {
        let chunks = Self.unicodeEventChunks(for: text)
        guard !chunks.isEmpty else { return true }
        guard let targetProcessID else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        for chunk in chunks {
            guard
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { return false }

            let utf16 = Array(chunk.utf16)
            utf16.withUnsafeBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(
                    stringLength: buffer.count,
                    unicodeString: buffer.baseAddress
                )
                keyUp.keyboardSetUnicodeString(
                    stringLength: buffer.count,
                    unicodeString: buffer.baseAddress
                )
            }
            keyDown.postToPid(targetProcessID)
            keyUp.postToPid(targetProcessID)
        }
        return true
    }

    private func directInputVerificationError(reason: String) -> NSError {
        NSError(
            domain: "AXTextInjector",
            code: 13,
            userInfo: [
                NSLocalizedDescriptionKey: "Direct text insertion could not be verified: \(reason)"
            ]
        )
    }
}
