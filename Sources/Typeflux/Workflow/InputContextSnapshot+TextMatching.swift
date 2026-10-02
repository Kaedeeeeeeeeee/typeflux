import Foundation

extension InputContextSnapshot {
    static func stringRange(from cfRange: CFRange, in text: String) -> Range<String.Index>? {
        guard cfRange.location >= 0, cfRange.length >= 0 else { return nil }
        guard cfRange.location <= Int.max - cfRange.length else { return nil }

        return utf16StringRange(from: cfRange, in: text)
    }

    static func normalizedSelectedText(
        _ selectedText: String?,
        fallback: String,
        limit: Int
    ) -> String? {
        let candidate = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? selectedText ?? ""
            : fallback
        guard !candidate.isEmpty else { return nil }
        return String(candidate.prefix(limit))
    }

    static func selectedTextRange(in text: String, selectedText: String) -> Range<String.Index>? {
        if let exact = text.range(of: selectedText) {
            return exact
        }

        let normalizedText = normalizedSearchTextWithMap(text)
        let normalizedSelection = normalizedSearchText(selectedText)
        guard !normalizedText.text.isEmpty, !normalizedSelection.isEmpty else { return nil }
        guard let normalizedRange = normalizedText.text.range(of: normalizedSelection)
            ?? bestPartialSelectedTextRange(in: normalizedText.text, normalizedSelection: normalizedSelection)
        else {
            return nil
        }

        let lowerOffset = normalizedText.text.distance(
            from: normalizedText.text.startIndex,
            to: normalizedRange.lowerBound
        )
        let upperOffset = normalizedText.text.distance(
            from: normalizedText.text.startIndex,
            to: normalizedRange.upperBound
        ) - 1
        guard
            lowerOffset >= 0,
            upperOffset >= lowerOffset,
            lowerOffset < normalizedText.map.count,
            upperOffset < normalizedText.map.count
        else {
            return nil
        }

        return normalizedText.map[lowerOffset].lowerBound ..< normalizedText.map[upperOffset].upperBound
    }

    static func normalizedSearchText(_ text: String) -> String {
        normalizedSearchTextWithMap(text).text
    }

    private static func utf16StringRange(from cfRange: CFRange, in text: String) -> Range<String.Index>? {
        let utf16 = text.utf16
        guard cfRange.location <= utf16.count else { return nil }
        guard cfRange.location + cfRange.length <= utf16.count else { return nil }

        let lowerUTF16 = utf16.index(utf16.startIndex, offsetBy: cfRange.location)
        let upperUTF16 = utf16.index(lowerUTF16, offsetBy: cfRange.length)
        guard
            let lowerBound = lowerUTF16.samePosition(in: text),
            let upperBound = upperUTF16.samePosition(in: text)
        else {
            return nil
        }
        return lowerBound ..< upperBound
    }

    private static func bestPartialSelectedTextRange(
        in normalizedText: String,
        normalizedSelection: String
    ) -> Range<String.Index>? {
        let minimumLength = 18
        guard normalizedSelection.count >= minimumLength else { return nil }

        let maximumLength = min(80, normalizedSelection.count)
        let minimumIndex = normalizedSelection.index(
            normalizedSelection.startIndex,
            offsetBy: minimumLength
        )
        let maximumIndex = normalizedSelection.index(
            normalizedSelection.startIndex,
            offsetBy: maximumLength
        )

        var index = maximumIndex
        while index >= minimumIndex {
            let candidate = String(normalizedSelection[..<index])
            if let range = normalizedText.range(of: candidate) {
                return range
            }
            if index == minimumIndex { break }
            index = normalizedSelection.index(before: index)
        }

        return nil
    }

    private static func normalizedSearchTextWithMap(_ text: String) -> (text: String, map: [Range<String.Index>]) {
        var normalized = ""
        var map: [Range<String.Index>] = []
        var index = text.startIndex

        while index < text.endIndex {
            let next = text.index(after: index)
            let character = text[index]
            if let normalizedCharacter = normalizedSearchCharacter(character) {
                normalized.append(normalizedCharacter)
                map.append(index ..< next)
            }
            index = next
        }

        return (normalized, map)
    }

    private static func normalizedSearchCharacter(_ character: Character) -> Character? {
        if character.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return nil
        }

        switch character {
        case "“", "”", "„", "‟", "＂":
            return "\""
        case "‘", "’", "‚", "‛", "＇":
            return "'"
        default:
            return Character(String(character).lowercased())
        }
    }
}
