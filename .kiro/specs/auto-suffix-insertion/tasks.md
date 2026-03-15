# Implementation Plan: Auto-Suffix Insertion

## Overview

Incrementally add auto-suffix insertion and auto-send Enter features to Wispr by modifying four existing files (`SettingsStore.swift`, `SettingsView.swift`, `StateManager.swift`, `TextInsertionService.swift`) and introducing one new file (`SuffixEditorView.swift`). Each task builds on the previous, starting with persistence, then UI, then core logic, and finally wiring everything together.

## Tasks

- [x] 1. Add new settings properties to SettingsStore
  - [x] 1.1 Add UserDefaults keys and properties for auto-suffix and auto-send Enter
    - Add `autoSuffixEnabled`, `autoSuffixText`, and `autoSendEnterEnabled` keys to the `Keys` enum in `SettingsStore.swift`
    - Add three new `@Observable` properties with `didSet` persistence guards matching the existing pattern
    - Set defaults: `autoSuffixEnabled = false`, `autoSuffixText = " "`, `autoSendEnterEnabled = false`
    - _Requirements: 1.1, 1.2, 5.1_

  - [x] 1.2 Add load/save support for the new properties
    - In `load()`, read the three new values from UserDefaults (with nil-check guard for booleans, direct string read for text)
    - In `save()`, persist all three new values
    - Initialize the properties in `init()` before `load()` is called
    - _Requirements: 1.3, 1.4, 1.5, 5.2, 5.3_

  - [x] 1.3 Write property test for settings persistence round-trip
    - **Property 1: Settings persistence round-trip**
    - Generate random Bool values for `autoSuffixEnabled` and `autoSendEnterEnabled`, and random String values for `autoSuffixText`
    - Write values to a `SettingsStore` instance, create a new instance from the same `UserDefaults`, and assert equality
    - **Validates: Requirements 1.3, 1.4, 5.2**

- [x] 2. Add settings UI controls in SettingsView
  - [x] 2.1 Add toggles and conditional text field to the After Transcription section
    - In `afterTranscriptionSection` in `SettingsView.swift`, add a `Toggle("Auto-Insert Suffix", isOn: $store.autoSuffixEnabled)` with accessibility hint
    - Conditionally show a `LabeledContent("Suffix")` with a `TextField` bound to `$store.autoSuffixText` when `autoSuffixEnabled` is true
    - Add a `Toggle("Auto-Send Enter", isOn: $store.autoSendEnterEnabled)` with accessibility hint
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 5.4, 5.5_

  - [x] 2.2 Update Restore Defaults to reset new settings
    - In `restoreDefaults()` in `SettingsView.swift`, add resets: `autoSuffixEnabled = false`, `autoSuffixText = " "`, `autoSendEnterEnabled = false`
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 2.3 Write unit tests for SettingsView UI behavior
    - Verify suffix text field appears when `autoSuffixEnabled` is on and hides when off
    - Verify both toggles have accessibility hints
    - Verify Restore Defaults resets all three new settings
    - _Requirements: 2.2, 2.3, 2.5, 4.1, 4.2, 4.3, 5.5_

- [x] 3. Add simulateEnterKey to TextInsertionService
  - [x] 3.1 Implement `simulateEnterKey()` method
    - Add a public `simulateEnterKey()` method to `TextInsertionService.swift`
    - Use CGEvent with virtual key code `0x24` (Return/Enter), posting key-down then key-up to `.cghidEventTap`
    - Follow the same pattern as the existing `simulateCommandV()` method
    - _Requirements: 5.6_

  - [x] 3.2 Add `simulateEnterKey()` to the `TextInserting` protocol
    - Add `func simulateEnterKey()` to the `TextInserting` protocol so mocks can track calls in tests
    - _Requirements: 5.6_

- [x] 4. Checkpoint - Verify settings and UI compile
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Integrate suffix and Enter logic in StateManager
  - [x] 5.1 Add helper methods to StateManager
    - Add `applyAutoSuffix(to:)` method that returns `text + autoSuffixText` when enabled and both strings are non-empty, otherwise returns original text
    - Add `applyAutoSendEnter()` method that calls `textInsertionService.simulateEnterKey()` when `autoSendEnterEnabled` is true
    - _Requirements: 3.1, 3.2, 3.3, 5.6, 5.7_

  - [x] 5.2 Modify `endRecording()` to apply suffix and Enter
    - After successful transcription in `endRecording()`, call `applyAutoSuffix(to:)` on `result.text` to get `finalText`
    - Pass `finalText` to `textInsertionService.insertText()`
    - Call `applyAutoSendEnter()` after successful text insertion
    - _Requirements: 3.1, 3.2, 3.3, 5.6, 5.7, 5.9_

  - [x] 5.3 Modify EOU handler to apply suffix and Enter
    - In the EOU monitoring handler within `startEouMonitoringIfSupported()`, apply the same suffix and Enter logic as `endRecording()`
    - Call `applyAutoSuffix(to:)` on `finalResult.text` before `insertText()`
    - Call `applyAutoSendEnter()` after successful text insertion
    - _Requirements: 3.4, 5.8, 5.9_

  - [x] 5.4 Write property test for suffix application correctness
    - **Property 2: Suffix application correctness**
    - Generate random non-empty transcription strings and random suffix configurations (`autoSuffixEnabled` Bool, `autoSuffixText` String)
    - Call `applyAutoSuffix(to:)` and verify output matches expected concatenation rule
    - **Validates: Requirements 3.1, 3.2, 3.3**

  - [x] 5.5 Write property test for Enter keystroke conditional execution
    - **Property 3: Enter keystroke conditional execution**
    - Generate random `autoSendEnterEnabled` values and use a mock `TextInsertionService` to record whether `simulateEnterKey()` was called
    - Assert the call happens if and only if the toggle is true
    - **Validates: Requirements 5.6, 5.7**

  - [x] 5.6 Write property test for operation ordering
    - **Property 4: Operation ordering when both features enabled**
    - Generate random text and suffix values with both features enabled
    - Use a mock `TextInsertionService` that records call order to verify `insertText()` is called before `simulateEnterKey()`
    - **Validates: Requirements 5.9**

  - [x] 5.7 Write unit tests for edge cases
    - Test empty suffix text results in no suffix appended (Requirement 3.3)
    - Test suffix disabled results in unmodified text (Requirement 3.2)
    - Test both features work in push-to-talk and hands-free modes (Requirements 3.4, 5.8)
    - _Requirements: 3.2, 3.3, 3.4, 5.7, 5.8_

- [x] 6. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties from the design document
- The `TextInserting` protocol enables mock-based testing of StateManager without CGEvent side effects
