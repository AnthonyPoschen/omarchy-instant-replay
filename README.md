# Instant Replay for Omarchy

Always-on instant replay for Omarchy, using the GPU Screen Recorder that
already ships with the distro. Buffer a monitor, a region, or a followed
window, then save the last N seconds with a click or a hotkey.

The plugin does not make network requests. Capture, Save, and Clip joining
all run on this machine.

## Install

```sh
omarchy plugin add https://github.com/AnthonyPoschen/omarchy-instant-replay.git --enable
```

Move it if you want it on the left:

```sh
omarchy bar move io.github.anthonyposchen.instant-replay --section left
```

Requires Omarchy 4 (Quickshell bar) plus `gpu-screen-recorder`, `gsr-cli`,
and `ffmpeg`, which Omarchy already installs.

## Use

- Left-click the bar icon to **Save** while Live, or to start the Replay
  Buffer when it is not.
- Right-click to open Settings.
- Middle-click to refresh status.

**Monitor Mode** (default) pins a named connector, or the focused output at
start. Moving focus later does not retarget.

**Follow Mode** tracks the focused window (with an Allowlist, Denylist, or
All filter). Changing monitors is a Split: Save still writes one Clip.

**Pin Mode** stays on one window from the picker. A glance at anything else
does not retarget.

**Region Mode** pins a rectangle on one monitor. Re-picking while Live is a
Split.

Clips land in `~/Videos/Replays` (or `$OMARCHY_SCREENRECORD_DIR/Replays`),
unless you set a clips folder in Settings.

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
should not treat the Replay Buffer as a session recording.

Only one KMS screen capture can run at a time. While the buffer is on, stock
`omarchy screenrecord` may fail to start. Turn the buffer off first if you want
a region or window take with the built-in recorder. This plugin never stops a
Session Recording to go Live.

## Settings

Mode is chosen first; the rest of the panel swaps. Encoder knobs sit in a
collapsed extras section. The Replay Buffer remembers whether it was on; the
shell starts it again if the last session was Live or Armed.

| Setting | Default | Meaning |
| --- | --- | --- |
| `mode` | `monitor` | `monitor`, `follow`, `pin`, or `region`. |
| `monitor` | empty | Capture this connector (`DP-1`, `HDMI-A-1`, …). Empty uses the focused monitor at start. |
| `seconds` | `60` | Rolling Replay Window, 15–7200. |
| `audio` | `desktop` | `none`, `desktop`, or `both` (desktop + microphone). Follow and Pin also offer `window` and `window-mic`. |
| `clipResolution` | `1080p` | Clip canvas: `720p`, `1080p`, `1440p`, or `2160p`. |
| `clipScale` | `fit` | How frames land on that canvas: `fit`, `stretch`, or `center`. |
| `outputDir` | empty | Where Save writes Clips. Empty uses Videos/Replays. Must be an absolute path. |

```sh
omarchy bar set io.github.anthonyposchen.instant-replay seconds 120 --json
omarchy bar set io.github.anthonyposchen.instant-replay audio desktop --json
```

## Files

| Path | What it is |
| --- | --- |
| `~/.config/omarchy-instant-replay/config` | Helper settings (mode, monitor, encoder, lists). |
| `~/.local/state/omarchy-instant-replay/` | Activity, PID, segments, save jobs, GSR log. |
| `$XDG_RUNTIME_DIR/omarchy-instant-replay/` | IPC socket and GSR output. Gone on logout. |
| `~/Videos/Replays/` (or your clips folder) | Saved Clips. Kept after plugin removal. |

An older `~/.config/omarchy-shadowplay/` config is copied once if the new
config file is missing.

## Remove

```sh
omarchy plugin remove io.github.anthonyposchen.instant-replay
```

That removes the plugin from the bar. It does not stop a Replay Buffer that
is still Live. Run `"$helper" stop` first, or reboot.

State under `~/.config/omarchy-instant-replay/` and
`~/.local/state/omarchy-instant-replay/` is left behind. Clips in
`~/Videos/Replays` (or your clips folder) are left behind. Delete those
directories yourself if you want them gone.

## Development

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
bash tests/test-helper.sh
```

## License

MIT
