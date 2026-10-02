import Foundation

enum WindowContextReducer {
    static let defaultCharacterLimit = 8000
    private static let maximumSegmentLength = 800
    private static let omissionMarker = "\n[... unrelated window content omitted ...]\n"

    static func reduce(
        _ text: String,
        query: String,
        anchors: [String] = [],
        characterLimit: Int = defaultCharacterLimit
    ) -> String {
        guard characterLimit > 0 else { return "" }

        let segments = normalizedSegments(from: text)
        guard !segments.isEmpty else { return "" }

        let completeText = segments.joined(separator: "\n")
        guard completeText.count > characterLimit else { return completeText }

        let terms = searchTerms(from: [query] + anchors)
        var selectedIndices = Set<Int>()
        includeBoundarySegments(in: segments, selectedIndices: &selectedIndices)

        let scored = segments.indices.map { index in
            let score = relevanceScore(
                for: segments[index],
                terms: terms,
                index: index,
                count: segments.count
            )
            return (index: index, score: score)
        }.sorted {
            if $0.score == $1.score { return $0.index > $1.index }
            return $0.score > $1.score
        }

        for candidate in scored where candidate.score > 0 {
            let previousIndices = selectedIndices
            for index in max(0, candidate.index - 1) ... min(segments.count - 1, candidate.index + 1) {
                selectedIndices.insert(index)
            }
            if renderedLength(segments: segments, indices: selectedIndices) > characterLimit {
                selectedIndices = previousIndices
            }
        }

        if renderedLength(segments: segments, indices: selectedIndices) < characterLimit {
            for index in segments.indices.reversed() where !selectedIndices.contains(index) {
                selectedIndices.insert(index)
                if renderedLength(segments: segments, indices: selectedIndices) > characterLimit {
                    selectedIndices.remove(index)
                }
            }
        }

        return bounded(render(segments: segments, indices: selectedIndices), limit: characterLimit)
    }

    private static func normalizedSegments(from text: String) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            var start = line.startIndex
            while start < line.endIndex {
                let end = line.index(start, offsetBy: maximumSegmentLength, limitedBy: line.endIndex)
                    ?? line.endIndex
                let segment = String(line[start ..< end])
                let deduplicationKey = segment.lowercased()
                if seen.insert(deduplicationKey).inserted {
                    result.append(segment)
                }
                start = end
            }
        }

        return result
    }

    private static func includeBoundarySegments(in segments: [String], selectedIndices: inout Set<Int>) {
        for index in segments.indices.prefix(2) {
            selectedIndices.insert(index)
        }
        for index in segments.indices.suffix(4) {
            selectedIndices.insert(index)
        }
    }

    private static func relevanceScore(
        for segment: String,
        terms: Set<String>,
        index: Int,
        count: Int
    ) -> Int {
        let normalized = segment.lowercased()
        var score = 0
        for term in terms where normalized.contains(term) {
            score += min(term.count, 12)
        }
        if count > 0 {
            score += index * 2 / count
        }
        return score
    }

    private static func searchTerms(from inputs: [String]) -> Set<String> {
        var terms = Set<String>()
        for input in inputs {
            let lowered = input.lowercased()
            let tokens = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
            terms.formUnion(tokens.prefix(80))

            let cjkRuns = lowered.split { character in
                !character.unicodeScalars.contains(where: isCJK)
            }
            for runSlice in cjkRuns.prefix(20) {
                let run = String(runSlice)
                if run.count <= 8 {
                    terms.insert(run)
                }
                let characters = Array(run)
                guard characters.count >= 2 else { continue }
                for index in 0 ..< min(characters.count - 1, 40) {
                    terms.insert(String(characters[index ... index + 1]))
                }
            }
        }
        return terms
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF,
             0x3040 ... 0x30FF, 0xAC00 ... 0xD7AF:
            true
        default:
            false
        }
    }

    private static func renderedLength(segments: [String], indices: Set<Int>) -> Int {
        render(segments: segments, indices: indices).count
    }

    private static func render(segments: [String], indices: Set<Int>) -> String {
        let sortedIndices = indices.sorted()
        var output: [String] = []
        var previousIndex: Int?

        for index in sortedIndices {
            if let previousIndex, index > previousIndex + 1 {
                output.append(omissionMarker)
            }
            output.append(segments[index])
            previousIndex = index
        }

        return output.joined(separator: "\n")
    }

    private static func bounded(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        guard limit > 1 else { return String(text.prefix(limit)) }
        return String(text.prefix(limit - 1)) + "…"
    }
}
