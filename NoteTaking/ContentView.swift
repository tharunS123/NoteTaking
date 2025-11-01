import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = NoteTakingViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemIndigo), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    header
                    Spacer(minLength: 16)
                    statusCard
                    summarySection
                    Spacer(minLength: 16)
                    recordButton
                }
                .padding()
            }
            .navigationTitle("Focus Notes")
            .toolbar { toolbarContent }
        }
        .alert("Permission Needed", isPresented: Binding(
            get: { viewModel.errorMessage == AudioRecorderError.microphoneAccessDenied.localizedDescription },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(AudioRecorderError.microphoneAccessDenied.localizedDescription)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil && viewModel.errorMessage != AudioRecorderError.microphoneAccessDenied.localizedDescription },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("Dismiss", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture brilliant ideas")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("Record lectures, interviews, and brainstorms. We will transcribe and craft beautiful notes for you.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .idle:
                Label("Ready to capture", systemImage: "waveform")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Tap the record button below to start.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            case .recording:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.red)
                Text("Listening…")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Tap stop to begin transcription.")
                    .foregroundStyle(.secondary)
            case .transcribing:
                ProgressView("Transcribing & summarizing…")
                    .progressViewStyle(.circular)
            case .ready(let summary):
                Label("Notes ready", systemImage: "checkmark.seal.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                Text("\(summary.notes.split(separator: "\n").first ?? "Your notes are ready.")")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }

    private var summarySection: some View {
        Group {
            switch viewModel.state {
            case .ready(let summary):
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeader(title: "Executive Summary", systemImage: "sparkles")
                        Text(summary.notes)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        SectionHeader(title: "Transcript", systemImage: "text.badge.checkmark")
                        Text(summary.transcript)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.top, 8)
                }
                .frame(maxHeight: 360)
            default:
                EmptyView()
            }
        }
        .animation(.spring(), value: viewModel.state)
    }

    private var recordButton: some View {
        Button(action: viewModel.toggleRecording) {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 96, height: 96)
                    .shadow(color: buttonBackgroundColor.opacity(0.45), radius: 20, x: 0, y: 12)

                Image(systemName: buttonIcon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                    .frame(width: 116, height: 116)
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if case .ready = viewModel.state {
                Button("Clear") {
                    viewModel.reset()
                }
                .tint(.white)
            }
        }
    }

    private var buttonBackgroundColor: Color {
        switch viewModel.state {
        case .recording:
            return .red
        case .transcribing:
            return .orange
        default:
            return .blue
        }
    }

    private var buttonIcon: String {
        switch viewModel.state {
        case .recording:
            return "stop.fill"
        case .transcribing:
            return "hourglass"
        default:
            return "mic.fill"
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
