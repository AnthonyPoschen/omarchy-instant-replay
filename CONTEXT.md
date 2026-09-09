# Instant Replay

Always-on instant replay for Omarchy. The user was not making a session recording; something worth keeping happened; one action writes the last N seconds to disk and the buffer keeps running.

## Language

**Replay Buffer**:
The rolling capture of the last N seconds, held until Save. It is not a file.
_Avoid_: recording, session recording, always recording

**Save**:
Write one Clip covering the Replay Window and keep the live Replay Buffer running. Segments are joined in private. There is no trim UI.

**Clip**:
The one video file the user gets from Save. It is the only user-visible video. Further trimming is the user's, in their own tools.
_Avoid_: recording, replay file, showing Segments as Clips

**Buffer Target**:
What the live Replay Buffer is pinned to: a monitor, or in Region Mode a rectangle. Changing it is a Split.

**Split**:
A Buffer Target change. The live Replay Buffer is flushed to a Segment, then a new Replay Buffer starts on the new target. Only one KMS capture can run at a time, so the old capture does not stay live.
_Avoid_: treating a Split as deleting history

**Segment**:
A finite clip on disk from one Buffer Target, kept only while it can still fall inside the Replay Window. Not a Clip. Not shown as a Replay.

**Replay Window**:
The last N seconds of follow time the user asked to keep. Save trims Segments and the live Replay Buffer to this window.

**Discard**:
Delete a Segment that is entirely older than the Replay Window. Staying on the new monitor long enough is what frees the previous Split.

**Session Recording**:
Stock Omarchy start/stop capture (`omarchy screenrecord`). This plugin does not own that job. The jobs do not overlap; the KMS device still does. Only one capture can run at a time. Neither capture kills the other. We never stop a Session Recording to go Live.
_Avoid_: using "record" for Save or for the Replay Buffer

**Capture Extent**:
Follow and Pin always crop Save to the Subject rectangle (a fullscreen Subject is the same as the monitor). Monitor Mode is the whole output. Region Mode is the rectangle. There is no extra Extent control.

**Subject**:
The window the Replay Buffer is following. On Wayland this is not a GPU Screen Recorder window capture. The Subject chooses which monitor is the Buffer Target, and which rectangle Window extent uses.
_Avoid_: recorded window, capture window

**Match List**:
An ordered list of window classes used when Follow Mode is on Allowlist. People add entries by picking a window (click it). Rules match Hyprland `class` / `initialClass`. List order is priority when no allowed window is focused.

**Blacklist**:
An ordered list of window classes used when Follow Mode is on Denylist. People add entries by picking a window (click it). Rules match Hyprland `class` / `initialClass`. Ships pre-populated with Omarchy chrome: bar, launcher, lock screen. The user can remove entries or empty it.

**Live**:
The Replay Buffer is encoding. Enable starts a Replay Buffer except Follow Allowlist with no Subject.

**Waiting**:
Follow Allowlist is on, but no listed window exists. The Replay Buffer is not encoding. The panel says Waiting, not Recording. A matching window going Live is what starts capture. This is not a silent full-output recording.

**Linger**:
After the last Subject is destroyed, dump its ring as a Segment (so Save keeps that window crop), then stay Live on that Buffer Target for one Replay Window with a full-output crop. A matching window that reopens reclaims the Subject; same monitor is not a Split. The linger gap and the reopen sit in the same buffer, including whatever was on that output in between. If nothing returns, Follow Allowlist goes Waiting; other Follow filters stay Live on that Buffer Target until a matching window returns or the user disables.

**Sticky Subject**:
When the focused window is not allowed to become the Subject, keep the last Subject. Alt-tab to Discord does not retarget. Linger is what happens after that window is gone.

**Follow Mode**:
UI name: Follow focused window. One mode with a **Filter**: Allowlist (Match List), Denylist (Blacklist), or All. Among windows the Filter allows, the focused one is the Subject. Otherwise Sticky. An allowed window on another monitor is a Split; Save stitches. A new Subject on the same monitor dumps the current ring as a Segment tagged with the old crop and clears the ring without stopping capture; Save stitches those Segments with the live buffer. Filter=All still ignores built-in Omarchy chrome (bar, launcher, lock); that is not the same as emptying the Denylist.
_Avoid_: Smart Follow as a top-level mode, Open

**Pin Mode**:
UI name: Window. One specific window: from the window picker, or the focused window when Enabled with none set yet (same idea as Monitor pinning the focused output at start). A glance at anything else does not retarget. If that window itself moves to another monitor, that is a Split; Save stitches. Not the same Settings control as Custom.

**Monitor Mode**:
No Subject. Dumb pin of one monitor: named connector, or focused output **at start**. Focus changes do not retarget. Default for a new install. A new install starts Enabled. After that, the last on/off state is restored when the shell loads. Follow, Pin, and Region are opt-in.
_Avoid_: Open Mode, simple start, follow focused output

**Region Mode**:
UI name: Custom. Dumb pin of a fixed rectangle, from the region picker. No Subject, no Filter, no smart swapping. The rectangle is persisted and must sit on one monitor. Re-picking while live is a Split. Not the same Settings control as Window. Fullscreen-window capture is Pin or Follow with Window extent, not Custom.

**Hotkey**:
A Hyprland bind the user installs themselves. The plugin cannot write their bind file. Settings copies `bindd` hyprlang with Save live (`SUPER + ALT + R`) and start, stop, toggle, open, and close commented out. `show`, `hide`, and `refresh` stay out of that list. The README lists the same set.

**Primary Action**:
Right-click the bar icon. Save when Live. Start when not.

**Settings**:
Left-click the bar icon. Save clip and Open clips stay on the main surface with the power switch. Mode, Filter, and Buffer Target sit in **Recording region**. Replay Window, audio, output folder, Clip Resolution, Clip Layout, Cursor, and keybinds sit in **Replay**. Encoder knobs sit in **Encoder**. All three sections are collapsed by default — not a nav menu. Match List, Blacklist, and Pin target apply while Live. Mode, Buffer Target, Replay Window length, audio, and encoder knobs Split if Live. The last session (Live, Waiting, or Off) is restored when the shell loads. A new install starts Enabled. Follow Save is always the Subject rectangle. Pin with no window yet pins the focused window and goes Live; if none (or only Omarchy chrome), Enable fails. Selecting Follow or Pin in Settings while Off does not start a session.

**Audio**:
What the Clip hears. **Audio to capture** is none, desktop, or (Follow/Window) the Subject's app stream. **Microphone** is a separate toggle for the default input. Audio none plus Microphone on is microphone only. Monitor Mode and Region Mode have no Window option. Changing audio or microphone Splits. A Follow Subject whose app stream changes Splits even on the same monitor.
_Avoid_: forcing system audio when the user asked for the game

**Clip Resolution**:
The fixed pixel size of the Clip. Not the Buffer Target size. Defaults to 1080p. Changing it does not Split.

**Clip Layout**:
How captured frames land on that canvas. **Fit** (default) scales to show the whole picture and adds bars. **Stretch** scales to the canvas and may distort aspect ratio. **Center** keeps native pixels, centered: bars if smaller, crop if larger. Changing it does not Split.

**Encoder Settings**:
User-visible GPU Screen Recorder knobs in Settings (codec, fps, quality, and similar). Hidden behind the collapsed Encoder section. Clip Resolution, Clip Layout, and Cursor live in Replay with Replay Window and audio.
