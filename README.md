# Instant Replay

Always-on instant replay for [Omarchy](https://omarchy.org/). Something worth keeping just happened. One action writes the last N seconds to disk and the Replay Buffer keeps running.

It uses the GPU Screen Recorder that already ships with Omarchy. Capture, Save, and Clip joining all run on this machine. The plugin does not make network requests.

Installable id: `io.github.anthonyposchen.instant-replay`.

## Install

```sh
omarchy plugin add https://github.com/AnthonyPoschen/omarchy-instant-replay.git --enable
```

Move the icon if you want it on the left:

```sh
omarchy bar move io.github.anthonyposchen.instant-replay --section left
```

Needs Omarchy 4 (Quickshell bar) plus `gpu-screen-recorder`, `gsr-cli`, and `ffmpeg`. Omarchy already installs those. The last-save Omacut icon needs the `omacut` package (default on Omarchy Quattro).

## Use the bar

| Action | What it does |
| --- | --- |
| Left-click | Open or close Settings. |
| Right-click | **Save** a Clip while Recording. |
| Middle-click | Refresh status. |

The disc is theme-colored when the buffer is off or Waiting, red when Recording, and three dots while a Clip is encoding. Settings shows **RECORDING**, **WAITING**, or **DISABLED**.

Clips land in `~/Videos/Replays` (or `$OMARCHY_SCREENRECORD_DIR/Replays`) unless you set a clips folder in Settings.

Save does not stop the Replay Buffer. Fitting the Clip to your canvas can use a lot of CPU. That ffmpeg job runs at nice 19 with idle I/O so a game keeps the cores.

## Set up for games

Follow plus Window audio keeps the Replay Buffer on the game and the Clip on that game's sound, not Discord or the rest of the desktop.

1. Left-click the bar icon.
2. Open **Recording region** and set **Mode** to Follow focused window.
3. Open **Replay** and set **Audio** to Window audio (or Window + microphone). Desktop audio is the default and records the whole system.
4. Back in **Recording region**, pick a **Filter**:
   - **Denylist** — skip chat, browser, and other non-games. Use **Pick window** on each one. The list already includes Omarchy chrome (bar, launcher, lock).
   - **Allowlist** — only the games you pick. Use **Pick window** on each game. List order is the fallback when none of them is focused.
5. Turn the switch on in the top-right of Settings with a game focused.

What happens after that:

- The focused window becomes the **Subject** if the Filter allows it, and the buffer goes **Recording**.
- **Denylist** does not scan for “any open game” at start. If Discord is focused when you start, the buffer still goes Recording on that monitor (full output) until you focus a window that is not on the Blacklist.
- **Allowlist** can take an already-open listed game even while Discord is focused. The focused allowed window still wins when there is one. If none of the listed windows exist, it **Waits** (toggle on, not recording) until one appears. Switching back to Allowlist with no listed window Waits immediately. It does not record the whole monitor.
- Alt-tab to a blocked window does not retarget (**Sticky**). The buffer stays on the game. When the game closes, it **Lingers** on that monitor for one Replay Window. Allowlist then Waits; other filters stay Recording on that output until a matching window returns.
- Save is cropped to the Subject rectangle. A fullscreen game is the same as the monitor. Window audio is that app's PipeWire stream, not system output.

Window mode is simpler if you only ever want one window. Monitor is the whole output and has no Window audio option.

## Choose a mode

Mode lives under **Recording region**. The rest of that section swaps to match.

### Monitor

Default. Pins one output: a named connector (`DP-1`, `HDMI-A-1`, …) or whichever monitor is focused **when the buffer starts**. Moving focus later does not retarget.

### Follow focused window

Tracks the focused window among those the Filter allows. Turning the switch on starts a Replay Buffer immediately, except **Allowlist** with no listed window: that **Waits** until a match exists.

- **All** — any window except built-in Omarchy chrome (bar, launcher, lock). Emptying the Denylist is not the same as All.
- **Allowlist** — only classes you pick. The focused allowed window is the Subject. If none is focused, the first open match in list order is. If none of those windows exist, it Waits (not Recording) instead of capturing the monitor.
- **Denylist** — skip classes you pick. Ships with Omarchy chrome; you can remove those entries. It does not pick some other open game for you.

The focused allowed window is the **Subject**. Alt-tab to Discord does not retarget (Sticky). An allowed window on another monitor is a **Split**: Save still writes one Clip. A new Subject on the same monitor dumps the current ring and Save stitches those pieces.

If the Subject closes, the buffer **Lingers** on that monitor for one Replay Window. Allowlist then Waits until a listed window returns; other filters stay Recording on that output.

Follow Save is always cropped to the Subject rectangle. A fullscreen Subject is the same as the monitor. Set Audio to Window audio if the Clip should hear the game and not the rest of the desktop.

### Window

Stays on one window from the picker. If you turn the switch on with none picked yet, it pins the focused window and goes Recording. Enable from the bar does not pin Omarchy chrome; pick a window first. A glance at anything else does not retarget. Switching to Window while already on keeps the Replay Buffer running on that pin. If that window moves to another monitor, that is a Split.

### Custom

Pins a rectangle on one monitor. Re-picking while Recording is a Split. Use Window or Follow if you want a fullscreen window, not Custom.

## Audio

| Setting | What the Clip hears |
| --- | --- |
| No audio | Video only. |
| Desktop audio | System output. Default. |
| Desktop + microphone | System output mixed with the default input. |
| Window audio | The Subject's app stream only. Follow and Window. |
| Window + microphone | Subject stream plus the default input. Follow and Window. |

Window audio is GPU Screen Recorder `app:name` from the window pid and PipeWire, not the Hyprland class. Java games (RuneLite and similar) often show up as `PipeWire ALSA [java]`. Discord's own window share still matches by pid on the Pulse node and may miss that stream. This plugin cannot inject audio into Discord's picker.

Changing audio while Recording is a Split.

## Clips

Save writes one file. There is no trim UI in this plugin. **Save clip** writes a Clip. **Open clips** opens the clips folder. After a Save, Settings shows the last path with a copy-path icon and the Omacut app icon; the Omacut icon opens that file in `omacut` so you can trim it there.

| Setting | Default | Meaning |
| --- | --- | --- |
| Replay Window | 60 seconds | How much follow time Save keeps (15–7200). |
| Resolution | 1080p | Canvas size: 720p, 1080p, 1440p, or 2160p. Not the capture size. |
| Layout | Fit | **Fit** scales the whole picture and adds bars. **Stretch** fills and may distort. **Center** keeps native pixels (bars if smaller, crop if larger). |

Changing clip resolution or layout does not Split.

## Hotkeys

Plugins cannot write Hyprland binds. Copy Hyprland keybinds from Settings, or paste this next to your other `bindd` lines. Save is live. The rest stay commented until you want them.

```hyprlang
bindd = SUPER ALT, R, Save replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay save
# bindd = SUPER ALT, S, Start replay buffer, exec, omarchy-shell io.github.anthonyposchen.instant-replay start
# bindd = SUPER ALT, X, Stop replay buffer, exec, omarchy-shell io.github.anthonyposchen.instant-replay stop
# bindd = SUPER ALT, T, Toggle Instant Replay panel, exec, omarchy-shell io.github.anthonyposchen.instant-replay toggle
# bindd = SUPER ALT, O, Open Instant Replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay open
# bindd = SUPER ALT, C, Close Instant Replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay close
```

`show`, `hide`, and `refresh` are not part of this set.

## Helper

After install, the helper is:

```sh
helper="$HOME/.config/omarchy/plugins/io.github.anthonyposchen.instant-replay/bin/omarchy-instant-replay"

"$helper" start
"$helper" save
"$helper" save 30
"$helper" stop
"$helper" status --json
"$helper" settings show --json
"$helper" doctor
```

`save 30` writes the last 30 seconds even if the Replay Window is longer.

## Stock Omarchy screen recording

This plugin starts GPU Screen Recorder as `omarchy-instant-replay-gsr`, so Alt+Print and the built-in recording indicator should not treat the Replay Buffer as a session recording.

Only one KMS screen capture can run at a time. While the buffer is on, `omarchy screenrecord` may fail to start. Turn the buffer off first if you want a stock take. This plugin never stops a Session Recording to go Live.

## Settings

Left-click the bar icon. The power switch is in the top-right. Status is **RECORDING** (buffer encoding), **WAITING** (Allowlist on, no listed window), or **DISABLED**.

On the main surface:

- **Save clip** writes a Clip while Recording.
- **Open clips** opens the clips folder.
- **Last save** (after a Clip exists): the file path, a copy-path icon, and the Omacut icon.

Then three collapsed groups, in this order. Each group draws a divider under its content when open.

| Section | What it holds |
| --- | --- |
| **Replay** | Output folder, Replay Window, audio, resolution, layout, cursor, Copy Hyprland keybinds. |
| **Recording region** | Mode (Monitor, Follow focused window, Window, Custom), Filter, Allowlist/Blacklist, monitor/pin/region pickers. |
| **Encoder** | Codec, FPS, quality, framerate mode, bitrate mode. |

Match List, Blacklist, and Pin target apply while Recording. Mode, Buffer Target, Replay Window, audio, and encoder knobs Split if Recording. Cursor, clip resolution, and layout do not Split.

The last session (Recording, Waiting, or Disabled) is restored when the shell loads. A new install starts Enabled. Use the top-right switch to turn it off; that choice is kept.

| Setting | Default | Meaning |
| --- | --- | --- |
| `mode` | `monitor` | `monitor`, `follow`, `pin`, or `region`. UI labels: Monitor, Follow focused window, Window, Custom. |
| `monitor` | empty | Connector to capture. Empty uses the focused monitor at start. |
| `seconds` | `60` | Replay Window, 15–7200. |
| `audio` | `desktop` | `none`, `desktop`, `both`. Follow and Window also offer `window` and `window-mic`. |
| `filter` | `all` | Follow only: `all`, `allowlist`, `denylist`. |
| `matchList` | empty | Allowlist window classes (comma-separated). |
| `blacklist` | Omarchy chrome | Denylist window classes. |
| `pinAddress` | empty | Hyprland client address for Window mode. |
| `region` | empty | Custom rectangle, `WxH+X+Y`. |
| `clipResolution` | `1080p` | Clip canvas. |
| `clipScale` | `fit` | `fit`, `stretch`, or `center`. |
| `codec` | `auto` | `auto`, `h264`, `hevc`, `av1`, `vp8`, `vp9`. |
| `fps` | `60` | Capture frame rate. |
| `quality` | `40000` | Encoder quality / bitrate knob. |
| `cursor` | `true` | Include the cursor. Lives in Replay, not Encoder. |
| `framerateMode` | `cfr` | `cfr` or `vfr`. |
| `bitrateMode` | `cbr` | `cbr` or `vbr`. |
| `outputDir` | empty | Absolute path for Clips. Empty uses Videos/Replays. |

```sh
omarchy bar set io.github.anthonyposchen.instant-replay seconds 120 --json
omarchy bar set io.github.anthonyposchen.instant-replay audio desktop --json
```

H.264 cannot capture a side longer than 4096 pixels (NVENC). A 5120×1440 output with codec `h264` falls back to HEVC so the buffer can go Recording. Set codec to `auto` or `hevc` if you want that to match the panel.

## Files

| Path | What it is |
| --- | --- |
| `~/.config/omarchy-instant-replay/config` | Helper settings. |
| `~/.local/state/omarchy-instant-replay/` | Activity, PID, segments, save jobs, GSR log. |
| `$XDG_RUNTIME_DIR/omarchy-instant-replay/` | IPC socket and GSR output. Gone on logout. |
| `~/Videos/Replays/` (or your clips folder) | Saved Clips. Kept after plugin removal. |

An older `~/.config/omarchy-shadowplay/` config is copied once if the new config file is missing.

## If something fails

**The buffer will not go Recording.** Only one KMS capture can run. Stop a stock `omarchy screenrecord` first. If the log says H.264 max resolution, use `auto` or `hevc`, or let the h264 fallback run.

**Settings says WAITING.** Follow Allowlist is on and no listed window is open. The Replay Buffer is not encoding. Focus a listed game, or change Filter.

**Window audio is silent.** The Hyprland class is not the PipeWire name. Java titles (RuneLite) are often `PipeWire ALSA [java]`. Check `"$helper" status --json` is live on the right Subject, then Save again.

**A Clip is encoding and the machine feels busy.** The bar shows three dots. ffmpeg is niced; it still uses spare cores. Wait it out or lower clip resolution.

**The bar icon did not update after you edited QML.** The shell loads `~/.config/omarchy/plugins/io.github.anthonyposchen.instant-replay/`, not a git checkout. Copy into that directory and run `omarchy restart shell`.

The GSR log is `~/.local/state/omarchy-instant-replay/gsr.log`.

## Remove

```sh
omarchy plugin remove io.github.anthonyposchen.instant-replay
```

That removes the plugin from the bar. It does not stop a Replay Buffer that is still Recording. Run `"$helper" stop` first, or reboot.

State under `~/.config/omarchy-instant-replay/` and `~/.local/state/omarchy-instant-replay/` is left behind. Clips stay in your clips folder. Delete those directories yourself if you want them gone.

## Development

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
bash tests/test-helper.sh
```

`tests/test-helper.sh` is the contract for start, save, stop, and monitor selection. It uses the fakes in `tests/`. Do not call a real GPU encoder from unit tests.

## License

MIT. See [LICENSE](LICENSE).
