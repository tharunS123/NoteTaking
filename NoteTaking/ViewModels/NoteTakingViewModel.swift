import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
final class NoteTakingViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case transcribing
        case ready(NoteSummary)
    }

    @Published private(set) var state: State = .idle
    @Published var errorMessage: String?

    private let recorder = AudioRecorder()
    private let transcriptionService = OpenRouterTranscriptionService()
    private var recordedFileURL: URL?

    func toggleRecording() {
        switch state {
        case .idle, .ready:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            break
        }
    }

    private func startRecording() {
        Task {
            do {
                let url = try await recorder.startRecording()
                await MainActor.run {
                    recordedFileURL = url
                    withAnimation {
                        state = .recording
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func stopRecording() {
        guard state == .recording else { return }
        let url = recorder.stopRecording()
        guard let recordingURL = url ?? recordedFileURL else {
            errorMessage = AudioRecorderError.recordingFailed.localizedDescription
            state = .idle
            return
        }

        state = .transcribing

        Task {
            do {
                let summary = try await transcriptionService.transcribeAndSummarize(from: recordingURL)
                await MainActor.run {
                    withAnimation {
                        state = .ready(summary)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    state = .idle
                }
            }
        }
    }

    func reset() {
        state = .idle
        recordedFileURL = nil
    }
}
