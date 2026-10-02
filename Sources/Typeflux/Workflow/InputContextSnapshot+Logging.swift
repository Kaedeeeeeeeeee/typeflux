import Foundation

extension InputContextSnapshot {
    static func logCapture(
        inputSnapshot: CurrentInputTextSnapshot,
        selectionSnapshot: TextSelectionSnapshot,
        context: InputContextSnapshot?
    ) {
        let selectedRangeDescription = inputSnapshot.selectedRange.map {
            "location=\($0.location), length=\($0.length)"
        } ?? "<nil>"
        let selectionRangeDescription = selectionSnapshot.selectedRange.map {
            "location=\($0.location), length=\($0.length)"
        } ?? "<nil>"
        let status = context == nil ? "skipped" : "captured"
        let skipReason = context == nil
            ? inputContextSkipReason(inputSnapshot: inputSnapshot, selectionSnapshot: selectionSnapshot)
            : "<none>"

        NetworkDebugLogger.logMessage(
            """
            [InputContext]
            status: \(status)
            skipReason: \(skipReason)
            inputFailureReason: \(inputSnapshot.failureReason ?? "<nil>")
            appName: \(inputSnapshot.processName ?? selectionSnapshot.processName ?? "<nil>")
            bundleIdentifier: \(inputSnapshot.bundleIdentifier ?? selectionSnapshot.bundleIdentifier ?? "<nil>")
            role: \(inputSnapshot.role ?? selectionSnapshot.role ?? "<nil>")
            inputTextSource: \(inputSnapshot.textSource ?? "<nil>")
            windowTextSource: \(inputSnapshot.windowTextSource ?? "<nil>")
            inputIsEditable: \(inputSnapshot.isEditable)
            inputIsFocusedTarget: \(inputSnapshot.isFocusedTarget)
            selectionSource: \(selectionSnapshot.source)
            selectionIsEditable: \(selectionSnapshot.isEditable)
            selectionIsFocusedTarget: \(selectionSnapshot.isFocusedTarget)
            selectedRange: \(selectedRangeDescription)
            selectionSelectedRange: \(selectionRangeDescription)
            inputTextLength: \(inputSnapshot.text?.count ?? 0)
            windowTextLength: \(inputSnapshot.windowText?.count ?? 0)
            selectedTextLength: \(context?.selectedText?.count ?? 0)
            prefixLength: \(context?.prefix.count ?? 0)
            suffixLength: \(context?.suffix.count ?? 0)
            """
        )
    }

    private static func inputContextSkipReason(
        inputSnapshot: CurrentInputTextSnapshot,
        selectionSnapshot: TextSelectionSnapshot
    ) -> String {
        guard selectionSnapshot.hasSelection else {
            return inputSnapshot.failureReason ?? "missing-input-and-selection-context"
        }
        if !inputSnapshot.isEditable {
            return inputSnapshot.failureReason ?? "focused-element-not-editable"
        }
        guard let text = inputSnapshot.text, !text.isEmpty else {
            return inputSnapshot.failureReason ?? "missing-input-text"
        }
        guard inputSnapshot.selectedRange != nil else {
            return "missing-selected-range"
        }
        return "invalid-selected-range-or-empty-context"
    }
}
