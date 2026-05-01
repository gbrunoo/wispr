//
//  MeetingStateManager.swift
//  wispr
//
//  Coordinator for meeting transcription mode.
//  Manages audio capture, continuous transcription, and transcript assembly.
//

import Foundation
import Observation
import AppKit
import UniformTypeIdentifiers
import os

/// State of the meeting transcription session.
enum MeetingState: Sendable, Equatable {
    case idle
    case recording
    case error(String)
}

/// Central coordinator for meeting transcription mode.
///
/// Orchestrates microphone capture, runs continuous chunked transcription,
/// and assembles a timestamped transcript.
///
/// Note: Currently captures microphone only. System audio capture (for remote
/// meeting participants) requires Screen Recording permission which is
/// incompatible with App Sandbox. Speaker labels default to "You" for all
/// entries until system audio support is added.
@MainActor
@Observable
final class MeetingStateManager {

    // MARK: - Published State

    /// Current meeting state.
    var meetingState: MeetingState = .idle

    /// The live transcript being built.
    var transcript: MeetingTranscript = MeetingTranscript()

    /// Audio level from microphone (0.0–1.0) for UI visualization.
    var micLevel: Float = 0

    /// Audio level from system audio (0.0–1.0) for UI visualization.
    /// Currently always 0 — system audio capture requires Screen Recording
    /// permission which is incompatible with App Sandbox.
    var systemLevel: Float = 0

    /// Error message, if any.
    var errorMessage: String?

    /// Whether the meeting window should be visible.
    var isWindowVisible: Bool = false

    /// Timer display string.
    var elapsedTime: String = "0:00"

    // MARK: - Dependencies

    private let meetingAudioEngine: MeetingAudioEngine
    private let transcriptionEngine: any TranscriptionEngine
    private let settingsStore: SettingsStore

    // MARK: - Tasks

    private var micTranscriptionTask: Task<Void, Never>?
    private var systemTranscriptionTask: Task<Void, Never>?
    private var micLevelTask: Task<Void, Never>?
    private var systemLevelTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        meetingAudioEngine: MeetingAudioEngine,
        transcriptionEngine: any TranscriptionEngine,
        settingsStore: SettingsStore
    ) {
        self.meetingAudioEngine = meetingAudioEngine
        self.transcriptionEngine = transcriptionEngine
        self.settingsStore = settingsStore
    }

    // MARK: - Meeting Lifecycle

    /// Starts a new meeting transcription session.
    func startMeeting() async {
        guard meetingState == .idle else { return }

        Log.stateManager.debug("MeetingStateManager — starting meeting")

        transcript = MeetingTranscript()
        errorMessage = nil

        do {
            let (micLevels, systemLevels) = try await meetingAudioEngine.startCapture()

            meetingState = .recording
            isWindowVisible = true

            // Start consuming audio levels for UI
            startMicLevelConsumption(micLevels)
            startSystemLevelConsumption(systemLevels)

            // Start parallel transcription on both audio streams
            startMicTranscription()
            startSystemTranscription()

            // Start elapsed time timer
            startTimer()

        } catch {
            Log.stateManager.error("MeetingStateManager — failed to start: \(error.localizedDescription)")
            await handleError("Failed to start meeting capture: \(error.localizedDescription)")
        }
    }

    /// Stops the meeting and finalizes the transcript.
    func stopMeeting() async {
        guard meetingState == .recording else { return }

        Log.stateManager.debug("MeetingStateManager — stopping meeting")

        // Flush remaining audio buffers before stopping
        await meetingAudioEngine.flushBuffers()

        // Give transcription task a moment to process final chunks
        try? await Task.sleep(for: .milliseconds(500))

        // Cancel all tasks
        micTranscriptionTask?.cancel()
        systemTranscriptionTask?.cancel()
        micLevelTask?.cancel()
        systemLevelTask?.cancel()
        timerTask?.cancel()

        micTranscriptionTask = nil
        systemTranscriptionTask = nil
        micLevelTask = nil
        systemLevelTask = nil
        timerTask = nil

        await meetingAudioEngine.stopCapture()

        meetingState = .idle
        micLevel = 0
        systemLevel = 0
    }

    /// Toggles between recording and stopped states.
    func toggleMeeting() async {
        switch meetingState {
        case .idle:
            await startMeeting()
        case .recording:
            await stopMeeting()
        case .error:
            meetingState = .idle
            errorMessage = nil
        }
    }

    /// Copies the transcript to the clipboard.
    func copyTranscript() {
        let text = transcript.asPlainText()
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Saves the transcript to a text file via save panel.
    func exportTranscript() {
        let text = transcript.asPlainText()
        guard !text.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "meeting-transcript-\(formattedDate()).txt"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                Log.stateManager.debug("MeetingStateManager — transcript exported to \(url.path)")
            } catch {
                Log.stateManager.error("MeetingStateManager — export failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Speaker Detection

    /// Whether the mic is currently active (you're speaking).
    /// Used to suppress system audio transcription during your speech,
    /// since meeting apps echo your voice back through system audio.
    private var isMicActive: Bool = false

    /// Timestamp of the last mic activity, used to debounce.
    private var lastMicActivityTime: Date = .distantPast

    /// How long after mic goes silent before we consider system audio as "Others" again.
    /// With a headset there's no acoustic echo, but meeting apps still mix your voice
    /// into the system audio output. A short debounce avoids cutting off others who
    /// start speaking right after you stop.
    private let micSuppressionDebounce: TimeInterval = 0.5

    // MARK: - Transcription

    private func startMicTranscription() {
        micTranscriptionTask = Task { [weak self] in
            guard let self else { return }
            let audioStream = await self.meetingAudioEngine.micAudioStream
            let language = self.settingsStore.languageMode

            for await chunk in audioStream {
                guard !Task.isCancelled else { break }
                guard chunk.count >= 8000 else { continue }

                // Check if mic chunk has meaningful audio (not silence)
                let rms = Self.rmsLevel(chunk)
                let hasSpeech = rms > 0.01

                await MainActor.run {
                    if hasSpeech {
                        self.isMicActive = true
                        self.lastMicActivityTime = Date()
                    } else {
                        // Debounce: only mark inactive after the suppression window
                        if Date().timeIntervalSince(self.lastMicActivityTime) > self.micSuppressionDebounce {
                            self.isMicActive = false
                        }
                    }
                }

                // Only transcribe if there's actual speech
                guard hasSpeech else { continue }

                do {
                    let result = try await self.transcriptionEngine.transcribe(chunk, language: language)
                    let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }

                    await MainActor.run {
                        self.transcript.entries.append(
                            MeetingTranscriptEntry(speaker: .you, text: text)
                        )
                    }
                } catch {
                    if case WisprError.emptyTranscription = error { continue }
                    Log.stateManager.warning("MeetingStateManager — mic transcription error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startSystemTranscription() {
        systemTranscriptionTask = Task { [weak self] in
            guard let self else { return }
            let audioStream = await self.meetingAudioEngine.systemAudioStream
            let language = self.settingsStore.languageMode

            for await chunk in audioStream {
                guard !Task.isCancelled else { break }
                guard chunk.count >= 8000 else { continue }

                // Suppress system transcription while mic is active.
                // When you're speaking, the meeting app echoes your voice
                // through system audio, causing duplicate "Others" entries.
                let micActive = await MainActor.run { self.isMicActive }
                if micActive {
                    Log.stateManager.debug("MeetingStateManager — suppressing system chunk (mic active)")
                    continue
                }

                do {
                    let result = try await self.transcriptionEngine.transcribe(chunk, language: language)
                    let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }

                    await MainActor.run {
                        self.transcript.entries.append(
                            MeetingTranscriptEntry(speaker: .others, text: text)
                        )
                    }
                } catch {
                    if case WisprError.emptyTranscription = error { continue }
                    Log.stateManager.warning("MeetingStateManager — system transcription error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Calculates the RMS (root mean square) level of an audio chunk.
    private static func rmsLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0.0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    // MARK: - Audio Level Consumption

    private func startMicLevelConsumption(_ stream: AsyncStream<Float>) {
        micLevelTask = Task { [weak self] in
            for await level in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.micLevel = level
                }
            }
        }
    }

    private func startSystemLevelConsumption(_ stream: AsyncStream<Float>) {
        systemLevelTask = Task { [weak self] in
            for await level in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.systemLevel = level
                }
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.elapsedTime = self?.transcript.formattedDuration ?? "0:00"
                }
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) async {
        meetingState = .error(message)
        errorMessage = message

        // Auto-dismiss after 5 seconds
        try? await Task.sleep(for: .seconds(5))
        if case .error = meetingState {
            meetingState = .idle
            errorMessage = nil
        }
    }

    // MARK: - Helpers

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
