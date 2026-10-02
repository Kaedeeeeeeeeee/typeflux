import Foundation

struct InputContextSnapshot: Equatable {
    static let defaultPrefixLimit = 500
    static let defaultSuffixLimit = 200
    static let defaultSelectionLimit = 2000

    let appName: String?
    let bundleIdentifier: String?
    let role: String?
    let isEditable: Bool
    let isFocusedTarget: Bool
    let prefix: String
    let suffix: String
    let selectedText: String?
    let windowTitle: String?
    let windowText: String?
    let windowTextSource: String?

    init(
        appName: String?,
        bundleIdentifier: String?,
        role: String?,
        isEditable: Bool,
        isFocusedTarget: Bool,
        prefix: String,
        suffix: String,
        selectedText: String?,
        windowTitle: String? = nil,
        windowText: String? = nil,
        windowTextSource: String? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.isEditable = isEditable
        self.isFocusedTarget = isFocusedTarget
        self.prefix = prefix
        self.suffix = suffix
        self.selectedText = selectedText
        self.windowTitle = windowTitle
        self.windowText = windowText
        self.windowTextSource = windowTextSource
    }

    var hasContent: Bool {
        !prefix.isEmpty || !suffix.isEmpty || !(selectedText?.isEmpty ?? true)
            || !(windowText?.isEmpty ?? true)
    }

    static func make(
        inputSnapshot: CurrentInputTextSnapshot,
        selectionSnapshot: TextSelectionSnapshot,
        prefixLimit: Int = defaultPrefixLimit,
        suffixLimit: Int = defaultSuffixLimit,
        selectionLimit: Int = defaultSelectionLimit
    ) -> InputContextSnapshot? {
        let localContext: InputContextSnapshot?
        if let context = rangedInputContext(
            inputSnapshot: inputSnapshot,
            selectionSnapshot: selectionSnapshot,
            prefixLimit: prefixLimit,
            suffixLimit: suffixLimit,
            selectionLimit: selectionLimit
        ) {
            localContext = context
        } else if !inputSnapshot.isEditable {
            if let context = documentContext(
                inputSnapshot: inputSnapshot,
                selectionSnapshot: selectionSnapshot,
                prefixLimit: prefixLimit,
                suffixLimit: suffixLimit,
                selectionLimit: selectionLimit
            ) {
                localContext = context
            } else {
                localContext = selectionOnlyContext(
                    inputSnapshot: inputSnapshot,
                    selectionSnapshot: selectionSnapshot,
                    selectionLimit: selectionLimit
                )
            }
        } else if let context = documentContext(
            inputSnapshot: inputSnapshot,
            selectionSnapshot: selectionSnapshot,
            prefixLimit: prefixLimit,
            suffixLimit: suffixLimit,
            selectionLimit: selectionLimit
        ) {
            localContext = context
        } else {
            localContext = selectionOnlyContext(
                inputSnapshot: inputSnapshot,
                selectionSnapshot: selectionSnapshot,
                selectionLimit: selectionLimit
            )
        }

        return contextByAttachingWindow(
            localContext,
            inputSnapshot: inputSnapshot,
            selectionSnapshot: selectionSnapshot
        )
    }

    private static func rangedInputContext(
        inputSnapshot: CurrentInputTextSnapshot,
        selectionSnapshot: TextSelectionSnapshot,
        prefixLimit: Int,
        suffixLimit: Int,
        selectionLimit: Int
    ) -> InputContextSnapshot? {
        guard inputSnapshot.isEditable || inputSnapshot.textSource == "application-state" else {
            return nil
        }
        guard
            let text = inputSnapshot.text,
            !text.isEmpty,
            let selectedRange = inputSnapshot.selectedRange,
            let range = stringRange(from: selectedRange, in: text)
        else {
            return nil
        }

        let selected = selectedRange.length > 0
            ? normalizedSelectedText(
                selectionSnapshot.selectedText,
                fallback: String(text[range]),
                limit: selectionLimit
            )
            : nil
        let prefix = String(text[..<range.lowerBound]).suffixCharacters(prefixLimit)
        let suffix = String(text[range.upperBound...]).prefixCharacters(suffixLimit)

        let snapshot = InputContextSnapshot(
            appName: inputSnapshot.processName ?? selectionSnapshot.processName,
            bundleIdentifier: inputSnapshot.bundleIdentifier ?? selectionSnapshot.bundleIdentifier,
            role: inputSnapshot.role ?? selectionSnapshot.role,
            isEditable: inputSnapshot.isEditable,
            isFocusedTarget: inputSnapshot.isFocusedTarget || selectionSnapshot.isFocusedTarget,
            prefix: prefix,
            suffix: suffix,
            selectedText: selected
        )
        return snapshot.hasContent ? snapshot : nil
    }

    private static func selectionOnlyContext(
        inputSnapshot: CurrentInputTextSnapshot,
        selectionSnapshot: TextSelectionSnapshot,
        selectionLimit: Int
    ) -> InputContextSnapshot? {
        guard let selected = normalizedSelectedText(
            selectionSnapshot.selectedText,
            fallback: "",
            limit: selectionLimit
        ) else {
            return nil
        }

        return InputContextSnapshot(
            appName: inputSnapshot.processName ?? selectionSnapshot.processName,
            bundleIdentifier: inputSnapshot.bundleIdentifier ?? selectionSnapshot.bundleIdentifier,
            role: selectionSnapshot.role ?? inputSnapshot.role,
            isEditable: inputSnapshot.isEditable || selectionSnapshot.isEditable,
            isFocusedTarget: inputSnapshot.isFocusedTarget || selectionSnapshot.isFocusedTarget,
            prefix: "",
            suffix: "",
            selectedText: selected
        )
    }

    private static func documentContext(
        inputSnapshot: CurrentInputTextSnapshot,
        selectionSnapshot: TextSelectionSnapshot,
        prefixLimit: Int,
        suffixLimit: Int,
        selectionLimit: Int
    ) -> InputContextSnapshot? {
        guard
            let documentText = inputSnapshot.text,
            !documentText.isEmpty,
            let selectedText = selectionSnapshot.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
            !selectedText.isEmpty,
            let range = selectedTextRange(in: documentText, selectedText: selectedText)
        else {
            return nil
        }

        let prefix = String(documentText[..<range.lowerBound]).suffixCharacters(prefixLimit)
        let suffix = String(documentText[range.upperBound...]).prefixCharacters(suffixLimit)
        let boundedSelectedText = String(selectedText.prefix(selectionLimit))
        let snapshot = InputContextSnapshot(
            appName: inputSnapshot.processName ?? selectionSnapshot.processName,
            bundleIdentifier: inputSnapshot.bundleIdentifier ?? selectionSnapshot.bundleIdentifier,
            role: inputSnapshot.role ?? selectionSnapshot.role,
            isEditable: inputSnapshot.isEditable || selectionSnapshot.isEditable,
            isFocusedTarget: inputSnapshot.isFocusedTarget || selectionSnapshot.isFocusedTarget,
            prefix: prefix,
            suffix: suffix,
            selectedText: boundedSelectedText
        )
        return snapshot.hasContent ? snapshot : nil
    }

}

private extension String {
    func prefixCharacters(_ limit: Int) -> String {
        guard limit > 0 else { return "" }
        return String(prefix(limit))
    }

    func suffixCharacters(_ limit: Int) -> String {
        guard limit > 0 else { return "" }
        return String(suffix(limit))
    }
}
