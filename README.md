# Instant Replay for Omarchy

Always-on instant replay for Omarchy, using the GPU Screen Recorder that
already ships with the distro. Buffer one monitor in the background, then save
the last N seconds with a click or a hotkey.

v0.1 records a **monitor**. Region and window-follow capture are later work:
on Wayland those are different backends, and changing the target restarts the
buffer.

## Install

```sh
omarchy plugin add https://github.com/AnthonyPoschen/omarchy-instant-replay.git --enable
```

Move it if you want it on the left:

```sh
omarchy bar move io.github.anthonyposchen.instant-replay --section left
```

Requires Omarchy 4 (Quickshell bar) plus `gpu-screen-recorder` and `gsr-cli`,
which Omarchy already installs.

## Use

- Left-click the bar icon to **Save** while Live, or to start the Replay Buffer
  in Monitor Mode when it is not.
- Right-click to open Settings.
- Middle-click to refresh status.

Monitor Mode pins a named connector, or the focused output **at start**. Moving
focus later does not retarget, because GPU Screen Recorder cannot change
capture source without dropping the buffer.

Clips land in `~/Videos/Replays` (or `$OMARCHY_SCREENRECORD_DIR/Replays`).

## Hotkey

Plugins cannot write Hyprland binds. Copy keybinds from Settings, or paste
this next to your other `bindd` lines. Save is live; the rest stay commented
until you want them. `show`, `hide`, and `refresh` are not part of this set.

```hyprlang
bindd = SUPER ALT, R, Save replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay save
# bindd = SUPER ALT, S, Start replay buffer, exec, omarchy-shell io.github.anthonyposchen.instant-replay start
# bindd = SUPER ALT, X, Stop replay buffer, exec, omarchy-shell io.github.anthonyposchen.instant-replay stop
# bindd = SUPER ALT, T, Toggle Instant Replay panel, exec, omarchy-shell io.github.anthonyposchen.instant-replay toggle
# bindd = SUPER ALT, O, Open Instant Replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay open
# bindd = SUPER ALT, C, Close Instant Replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay close
```

You can also call the helper directly after install:

```sh
helper="$HOME/.config/omarchy/plugins/io.github.anthonyposchen.instant-replay/bin/omarchy-instant-replay"
"$helper" start
"$helper" save
"$helper" save 30
"$helper" stop
"$helper" status --json
```

## Stock Omarchy screen recording

This plugin starts GPU Screen Recorder under the process name
`omarchy-instant-replay-gsr`, so Alt+Print and the built-in recording indicator
should not treat the replay buffer as a session recording.

Only one KMS screen capture can run at a time. While the buffer is on, stock
`omarchy screenrecord` may fail to start. Turn the buffer off first if you want
a region or window take with the built-in recorder.

## Settings

Monitor Mode only for v0.1: mode, monitor, Replay Window length, and audio.
Encoder knobs sit in collapsed extras. The Replay Buffer remembers whether
it was on; the shell starts it again if the last session was Live or Armed.

| Setting | Default | Meaning |
| --- | --- | --- |
| `monitor` | empty | Capture this connector (`DP-1`, `HDMI-A-1`, …). Empty uses the focused monitor at start. |
| `seconds` | `60` | Rolling Replay Window, 15–7200. |
| `audio` | `desktop` | `none`, `desktop`, or `both` (desktop + microphone). |

```sh
omarchy bar set io.github.anthonyposchen.instant-replay seconds 120 --json
omarchy bar set io.github.anthonyposchen.instant-replay audio desktop --json
```

## Development

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
bash tests/test-helper.sh
```

## License

MIT
