import AVFoundation
import Foundation

enum AudioRecorderError: LocalizedError {
    case microphoneAccessDenied
    case recordingFailed
    case recorderUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is required to capture audio. Please enable it in Settings."
        case .recordingFailed:
            return "Recording could not start. Please try again."
        case .recorderUnavailable:
            return "Recording resources are currently unavailable."
        }
    }
}

final class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    private let fileManager = FileManager.default

    func requestPermission() async throws {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return
        case .denied:
            throw AudioRecorderError.microphoneAccessDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            guard granted else { throw AudioRecorderError.microphoneAccessDenied }
        @unknown default:
            throw AudioRecorderError.microphoneAccessDenied
        }
    }

    func startRecording() async throws -> URL {
        try await requestPermission()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let recordingURL = makeRecordingURL()
        try prepareRecorder(at: recordingURL)
        guard let audioRecorder else { throw AudioRecorderError.recorderUnavailable }

        guard audioRecorder.record() else {
            throw AudioRecorderError.recordingFailed
        }

        return recordingURL
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        let url = audioRecorder?.url
        audioRecorder = nil
        return url
    }

    private func prepareRecorder(at url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        audioRecorder = try AVAudioRecorder(url: url, settings: recordingSettings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
    }

    private func makeRecordingURL() -> URL {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let fileName = "Recording-\(ISO8601DateFormatter().string(from: Date())).m4a"
        return cachesDirectory.appendingPathComponent("Recordings", isDirectory: true).appendingPathComponent(fileName)
    }
}
