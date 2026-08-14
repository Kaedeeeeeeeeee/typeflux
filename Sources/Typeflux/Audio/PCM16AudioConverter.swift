import AVFoundation
import Foundation

enum PCM16AudioConverter {
    static let targetSampleRate: Double = 16_000
    static let chunkSize = 3_200

    static func convert(url: URL) throws -> Data {
        let sourceFile = try AVAudioFile(forReading: url)
        let sourceFormat = sourceFile.processingFormat
        let totalSourceFrames = AVAudioFrameCount(sourceFile.length)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw conversionError(code: 1, message: "Failed to create target audio format.")
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw conversionError(code: 2, message: "Failed to create audio converter.")
        }

        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: totalSourceFrames
        ) else {
            throw conversionError(code: 3, message: "Failed to allocate source buffer.")
        }
        try sourceFile.read(into: sourceBuffer)

        let ratio = targetSampleRate / sourceFormat.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(totalSourceFrames) * ratio) + 512
        guard let targetBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: targetCapacity
        ) else {
            throw conversionError(code: 4, message: "Failed to allocate target buffer.")
        }

        var hasProvidedInput = false
        var convertError: NSError?
        let status = converter.convert(to: targetBuffer, error: &convertError) { _, outStatus in
            if hasProvidedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasProvidedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let convertError {
            throw convertError
        }
        guard status != .error else {
            throw conversionError(code: 5, message: "Audio conversion failed.")
        }

        let bytesPerFrame = Int(targetFormat.streamDescription.pointee.mBytesPerFrame)
        let byteCount = Int(targetBuffer.frameLength) * bytesPerFrame
        guard let channelData = targetBuffer.int16ChannelData else {
            return Data()
        }
        return Data(bytes: channelData[0], count: byteCount)
    }

    private static func conversionError(code: Int, message: String) -> NSError {
        NSError(
            domain: "PCM16AudioConverter",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
