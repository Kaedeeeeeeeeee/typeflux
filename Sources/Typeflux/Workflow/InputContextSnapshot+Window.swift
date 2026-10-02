import Foundation

extension InputContextSnapshot {
    static func contextByAttachingWindow(
        _ localContext: InputContextSnapshot?,
        inputSnapshot: CurrentInputTextSnapshot,
        selectionSnapshot: TextSelectionSnapshot
    ) -> InputContextSnapshot? {
        let windowText = inputSnapshot.windowText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let localContext else {
            guard let windowText, !windowText.isEmpty else { return nil }
            return InputContextSnapshot(
                appName: inputSnapshot.processName ?? selectionSnapshot.processName,
                bundleIdentifier: inputSnapshot.bundleIdentifier ?? selectionSnapshot.bundleIdentifier,
                role: inputSnapshot.role ?? selectionSnapshot.role,
                isEditable: inputSnapshot.isEditable || selectionSnapshot.isEditable,
                isFocusedTarget: inputSnapshot.isFocusedTarget || selectionSnapshot.isFocusedTarget,
                prefix: "",
                suffix: "",
                selectedText: nil,
                windowTitle: inputSnapshot.windowTitle ?? selectionSnapshot.windowTitle,
                windowText: windowText,
                windowTextSource: inputSnapshot.windowTextSource
            )
        }

        return InputContextSnapshot(
            appName: localContext.appName,
            bundleIdentifier: localContext.bundleIdentifier,
            role: localContext.role,
            isEditable: localContext.isEditable,
            isFocusedTarget: localContext.isFocusedTarget,
            prefix: localContext.prefix,
            suffix: localContext.suffix,
            selectedText: localContext.selectedText,
            windowTitle: inputSnapshot.windowTitle ?? selectionSnapshot.windowTitle,
            windowText: windowText,
            windowTextSource: inputSnapshot.windowTextSource
        )
    }
}
