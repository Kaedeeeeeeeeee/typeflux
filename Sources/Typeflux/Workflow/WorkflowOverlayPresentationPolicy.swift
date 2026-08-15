import Foundation

enum WorkflowOverlayPresentationPolicy {
    static func shouldShowRecordingTranscriptionPreview() -> Bool {
        // Keep realtime transcription running for final-result latency and fallback
        // recovery, but leave the recording capsule compact until text is applied.
        false
    }

    static func shouldShowProcessingAfterRecording() -> Bool {
        // Once audio capture ends, the overlay should always leave the recording state.
        // Some windows can only return a final dialog instead of allowing write-back, but
        // that should still show a processing state rather than looking stuck on recording.
        true
    }

    static func shouldPresentResultDialog(for snapshot: TextSelectionSnapshot) -> Bool {
        snapshot.hasAskSelectionContext && !snapshot.canReplaceSelection
    }

    static func shouldShowLLMStreamingPreviewAfterTranscription() -> Bool {
        // The live subtitle surface belongs to speech recognition. LLM rewrites can
        // arrive as one large final chunk near the end of the thinking phase; showing
        // that chunk in the same surface makes the overlay look like a transient result
        // dialog while it is still labelled as thinking.
        false
    }

    static func shouldShowLLMStreamingPreviewForPersonaSelectionApplication() -> Bool {
        // Applying a persona to selected text has the same UX shape as post-dictation
        // rewriting: the user should see a stable thinking state until the final text is
        // applied or intentionally presented in a result dialog.
        false
    }
}
