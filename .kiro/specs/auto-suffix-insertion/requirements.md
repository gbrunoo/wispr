# Requirements Document

## Introduction

This feature adds an auto-suffix insertion capability and an optional auto-send Enter keystroke to Wispr. After the speech recognition engine transcribes and inserts text, the application optionally appends a user-configured string of characters (e.g., a space, or ". " for a period followed by a space). Additionally, a separate toggle allows the application to simulate pressing Enter/Return after text insertion, useful for automatically sending messages in chat applications. Both features are independently controlled by toggles in Settings (both default: off).

## Glossary

- **Wispr**: The macOS menu bar dictation application.
- **SettingsStore**: The persistent settings store that holds all user preferences via UserDefaults.
- **TextInsertionService**: The service responsible for inserting transcribed text at the cursor position in the frontmost application.
- **StateManager**: The central coordinator managing application state transitions and orchestrating all services.
- **Suffix**: A user-defined string of characters appended to the end of transcribed text before insertion.
- **Auto-Send Enter**: An optional feature that simulates pressing the Enter/Return key after text insertion, enabling automatic message sending in chat applications.
- **SettingsView**: The SwiftUI settings panel where users configure Wispr preferences.

## Requirements

### Requirement 1: Suffix Setting Persistence

**User Story:** As a user, I want my auto-suffix preference to be saved between app launches, so that I do not have to reconfigure the suffix each time I open Wispr.

#### Acceptance Criteria

1. THE SettingsStore SHALL persist an `autoSuffixEnabled` boolean property with a default value of `false`.
2. THE SettingsStore SHALL persist an `autoSuffixText` string property with a default value of `" "` (a space).
3. WHEN the user changes the `autoSuffixEnabled` toggle, THE SettingsStore SHALL persist the new value to UserDefaults immediately.
4. WHEN the user changes the `autoSuffixText` value, THE SettingsStore SHALL persist the new value to UserDefaults immediately.
5. WHEN Wispr launches, THE SettingsStore SHALL load the persisted `autoSuffixEnabled` and `autoSuffixText` values from UserDefaults.

### Requirement 2: Settings UI

**User Story:** As a user, I want to configure the auto-suffix feature from the Settings panel, so that I can enable or disable it and choose which characters to append.

#### Acceptance Criteria

1. THE SettingsView SHALL display a toggle labeled "Auto-Insert Suffix" in the After Transcription section.
2. WHEN the `autoSuffixEnabled` toggle is on, THE SettingsView SHALL display a text field labeled "Suffix" allowing the user to enter the suffix characters.
3. WHEN the `autoSuffixEnabled` toggle is off, THE SettingsView SHALL hide the suffix text field.
4. THE SettingsView SHALL bind the toggle to `SettingsStore.autoSuffixEnabled` and the text field to `SettingsStore.autoSuffixText`.
5. THE SettingsView toggle SHALL include an accessibility hint describing the feature purpose.

### Requirement 3: Suffix Appended to Transcribed Text

**User Story:** As a user, I want the configured suffix to be automatically appended after my dictated text, so that I do not have to manually type punctuation or spacing after each dictation.

#### Acceptance Criteria

1. WHILE `autoSuffixEnabled` is true, WHEN the StateManager completes a transcription and the transcribed text is non-empty, THE StateManager SHALL append the `autoSuffixText` value to the transcribed text before passing the combined string to the TextInsertionService.
2. WHILE `autoSuffixEnabled` is false, THE StateManager SHALL pass the transcribed text to the TextInsertionService without modification.
3. WHILE `autoSuffixEnabled` is true, WHEN the `autoSuffixText` value is an empty string, THE StateManager SHALL pass the transcribed text to the TextInsertionService without modification.
4. THE StateManager SHALL apply the suffix in both push-to-talk mode (hotkey release) and hands-free mode (end-of-utterance detection).

### Requirement 4: Restore Defaults

**User Story:** As a user, I want the Restore Defaults action to reset the auto-suffix settings, so that I can return to the original configuration.

#### Acceptance Criteria

1. WHEN the user activates "Restore Defaults" in SettingsView, THE SettingsView SHALL reset `autoSuffixEnabled` to `false`.
2. WHEN the user activates "Restore Defaults" in SettingsView, THE SettingsView SHALL reset `autoSuffixText` to `" "`.
3. WHEN the user activates "Restore Defaults" in SettingsView, THE SettingsView SHALL reset `autoSendEnterEnabled` to `false`.

### Requirement 5: Auto-Send Enter Keystroke

**User Story:** As a user, I want Wispr to optionally press Enter after inserting my dictated text, so that my message is automatically sent in chat and messaging applications without manual key presses.

#### Acceptance Criteria

1. THE SettingsStore SHALL persist an `autoSendEnterEnabled` boolean property with a default value of `false`.
2. WHEN the user changes the `autoSendEnterEnabled` toggle, THE SettingsStore SHALL persist the new value to UserDefaults immediately.
3. WHEN Wispr launches, THE SettingsStore SHALL load the persisted `autoSendEnterEnabled` value from UserDefaults.
4. THE SettingsView SHALL display a toggle labeled "Auto-Send Enter" in the After Transcription section, independent from the "Auto-Insert Suffix" toggle.
5. THE SettingsView toggle for "Auto-Send Enter" SHALL include an accessibility hint describing the feature purpose.
6. WHILE `autoSendEnterEnabled` is true, WHEN the StateManager completes text insertion, THE StateManager SHALL simulate an Enter/Return keystroke after the inserted text and after any suffix appended by the auto-suffix feature.
7. WHILE `autoSendEnterEnabled` is false, THE StateManager SHALL not simulate any Enter/Return keystroke after text insertion.
8. THE StateManager SHALL apply the auto-send Enter keystroke in both push-to-talk mode (hotkey release) and hands-free mode (end-of-utterance detection).
9. WHILE both `autoSuffixEnabled` and `autoSendEnterEnabled` are true, THE StateManager SHALL apply operations in the following order: transcribed text, then suffix, then Enter keystroke.
