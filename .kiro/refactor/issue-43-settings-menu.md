# Issue #43 — Settings menu item (⌘,) opens empty window

## Problem

Users clicking "Settings…" (⌘,) in the application menu see nothing happen
or an empty window. The standard macOS Settings menu item was wired to an
empty `Settings { EmptyView() }` SwiftUI scene, while the real settings
window is managed imperatively by `MenuBarController.openSettings()`.

## Root Cause

`WisprApp.body` declares a `Settings` scene with `EmptyView()` so macOS
shows the menu item and ⌘, shortcut. But since all windows are created
imperatively via `NSWindow` + `NSHostingController` (required for
accessory/menu-bar-only apps), the SwiftUI scene body is never useful.

When the user triggers ⌘, or clicks "Settings…", macOS sends the
`showSettingsWindow:` action up the responder chain. With no override,
it opens the empty SwiftUI scene.

## Fix

- [x] Override `showSettingsWindow:` in `WisprAppDelegate` to forward to `menuBarController?.openSettings()`
- [x] Keep the empty `Settings` scene so macOS continues to show the menu item
- [x] Verify build and tests pass

## Code Change

In `wisprApp.swift`, added to `WisprAppDelegate`:

```swift
@objc func showSettingsWindow(_ sender: Any?) {
    menuBarController?.openSettings()
}
```

Single method, no other changes needed. The delegate already holds a
reference to `menuBarController`, and `openSettings()` handles window
reuse (brings existing window to front if already open).
