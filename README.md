# ShadowPlay for Omarchy

Always-on instant replay for Omarchy, using the GPU Screen Recorder that
already ships with the distro. Buffer one monitor in the background, then save
the last N seconds with a click or a hotkey.

v0.1 records a **monitor**. Region and window-follow capture are later work:
on Wayland those are different backends, and changing the target restarts the
buffer.

## Install

```sh
omarchy plugin add https://github.com/AnthonyPoschen/omarchy-shadowplay.git --enable
```

Move it if you want it on the left:

```sh
omarchy bar move io.github.anthonyposchen.shadowplay --section left
```

Requires Omarchy 4 (Quickshell bar) plus `gpu-screen-recorder` and `gsr-cli`,
which Omarchy already installs.

## Use

- Left-click the bar icon to save a clip while the buffer is running, or to
  open the panel when it is not.
- Right-click to open the panel.
- Middle-click to refresh status.

In the panel, turn the buffer on, pick a monitor (or “Focused monitor”), choose
how many seconds to keep, and choose audio. **Focused monitor** is resolved
when the buffer starts. Moving focus later does not retarget, because GPU
Screen Recorder cannot change capture source without dropping the buffer.

Clips land in `~/Videos/Replays` (or `$OMARCHY_SCREENRECORD_DIR/Replays`).

## Hotkey

Plugins cannot install Hyprland binds. Add one in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + R", "Save replay", "omarchy-shell io.github.anthonyposchen.shadowplay save")
```

You can also call the helper directly after install:

```sh
helper="$HOME/.config/omarchy/plugins/io.github.anthonyposchen.shadowplay/bin/omarchy-shadowplay"
"$helper" start
"$helper" save
"$helper" save 30
"$helper" stop
"$helper" status --json
```

## Stock Omarchy screen recording

This plugin starts GPU Screen Recorder under the process name
`omarchy-shadowplay-gsr`, so Alt+Print and the built-in recording indicator
should not treat the replay buffer as a session recording.

Only one KMS screen capture can run at a time. While the buffer is on, stock
`omarchy screenrecord` may fail to start. Turn the buffer off first if you want
a region or window take with the built-in recorder.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `monitor` | empty | Capture this connector (`DP-1`, `HDMI-A-1`, …). Empty uses the focused monitor at start. |
| `seconds` | `60` | Rolling buffer length, 15–600. |
| `audio` | `desktop` | `none`, `desktop`, or `both` (desktop + microphone). |
| `autostart` | `false` | Start the buffer when the bar widget loads. |

```sh
omarchy bar set io.github.anthonyposchen.shadowplay seconds 120 --json
omarchy bar set io.github.anthonyposchen.shadowplay audio desktop --json
omarchy bar set io.github.anthonyposchen.shadowplay autostart true --json
```

## Development

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
bash tests/test-helper.sh
```

## License

MIT
