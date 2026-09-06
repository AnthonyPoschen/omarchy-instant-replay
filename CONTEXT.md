# ShadowPlay

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

**Blacklist**:
An ordered list of window classes used when Follow Mode is on Denylist. People add entries by picking a window (click it). Rules match Hyprland `class` / `initialClass`. Ships pre-populated with Omarchy chrome: bar, launcher, lock screen. The user can remove entries or empty it.

**Armed**:
The helper is running and watching. The Replay Buffer may be idle. Monitor Mode and Region Mode skip this and go Live when toggled on.

**Live**:
The Replay Buffer is encoding.

**Linger**:
After the last Subject is destroyed, dump its ring as a Segment (so Save keeps that window crop), then stay Live on that Buffer Target for one Replay Window with a full-output crop. A matching window that reopens reclaims the Subject; same monitor is not a Split. The linger gap and the reopen sit in the same buffer, including whatever was on that output in between. If nothing returns, stop and go back to Armed.

**Sticky Subject**:
When the focused window is not allowed to become the Subject, keep the last Subject. Alt-tab to Discord does not retarget. Linger is what happens after that window is gone.

**Follow Mode**:
UI name: Follow active window. One mode with a **Filter**: Denylist (Blacklist) or All. Among windows the Filter allows, the focused one is the Subject. Otherwise Sticky. An allowed window on another monitor is a Split; Save stitches. A new Subject on the same monitor dumps the current ring as a Segment tagged with the old crop and clears the ring without stopping capture; Save stitches those Segments with the live buffer. Filter=All still ignores built-in Omarchy chrome (bar, launcher, lock); that is not the same as emptying the Denylist.
_Avoid_: Smart Follow as a top-level mode, Open

**Pin Mode**:
One specific window, from the window picker. A glance at anything else does not retarget. If that window itself moves to another monitor, that is a Split; Save stitches. Not the same Settings control as Region.

**Monitor Mode**:
No Subject. Dumb pin of one monitor: named connector, or focused output **at start**. Focus changes do not retarget. Default for a new install; the Replay Buffer stays off until the user starts it. After that, the last on/off state is restored when the shell loads. Follow, Pin, and Region are opt-in.
_Avoid_: Open Mode, simple start, follow focused output

**Region Mode**:
Dumb ShadowPlay on a fixed rectangle, from the region picker. No Subject, no Filter, no smart swapping. The rectangle is persisted and must sit on one monitor. Re-picking while live is a Split. Not the same Settings control as Pin. Fullscreen-window capture is Pin or Follow with Window extent, not Region.

**Hotkey**:
A Hyprland bind the user installs themselves. The plugin cannot write `bindings.lua`. Settings copies an `o.bind` lua snippet with Save live (`SUPER + ALT + R`) and start, stop, toggle, open, and close commented out. `show`, `hide`, and `refresh` stay out of that list. The README lists the same set, lua first, then hyprlang.

**Primary Action**:
Left-click the bar icon. Save when Live. Start or arm when not, according to mode.

**Settings**:
Right-click the bar icon. Shows only the controls the current mode needs. Mode is chosen first; the rest of the panel swaps. Encoder knobs sit in a collapsible section, collapsed by default — not a nav menu. Blacklist and Pin target apply while Live. Mode, Buffer Target, Replay Window length, audio, and encoder knobs Split if Live. The last session (Live, Armed, or Off) is restored when the shell loads. Follow Save is always the Subject rectangle.

**Audio**:
What the Clip hears. **Desktop** is the system output. **Window** is the Subject's application stream (GPU Screen Recorder `app:name`, matched from the window pid/class and PipeWire), so Discord and music stay out. **+ microphone** mixes in the default input. Monitor Mode and Region Mode have no Window option. Changing audio Splits. A Follow Subject whose app stream changes Splits even on the same monitor.
_Avoid_: forcing system audio when the user asked for the game

**Clip Resolution**:
The fixed pixel size of the Clip. Not the Buffer Target size. Defaults to 1080p. Changing it does not Split.

**Clip Layout**:
How captured frames land on that canvas. **Fit** (default) scales to show the whole picture and adds bars. **Stretch** scales to the canvas and may distort aspect ratio. **Center** keeps native pixels, centered: bars if smaller, crop if larger. Changing it does not Split.

**Encoder Settings**:
User-visible GPU Screen Recorder knobs in Settings (codec, fps, quality, cursor, and similar). Hidden behind a collapsed section so Monitor Mode still looks like v0.1. Clip Resolution and Clip Layout are main Settings controls, not encoder extras.
