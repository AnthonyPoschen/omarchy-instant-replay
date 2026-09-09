# Instant Replay

Keep the last few seconds of your screen on Omarchy, then save them after something worth keeping already happened.

You do not hit record before a play. The plugin holds a rolling buffer in the background. When you want the moment, one action writes a video file and the buffer keeps going.

That is the same idea as NVIDIA ShadowPlay or Xbox Game DVR, built on the GPU Screen Recorder Omarchy already ships. Capture and save stay on this machine. The plugin does not make network requests.

A new install starts enabled on your focused monitor, last 60 seconds, desktop audio, 1080p clips. Open Settings from the bar if you want a different slice of the screen, only the game's sound, or a longer window.

## Install

```sh
omarchy plugin add https://github.com/AnthonyPoschen/omarchy-instant-replay.git --enable
```

Move the icon if you want it on the left:

```sh
omarchy bar move io.github.anthonyposchen.instant-replay --section left
```

You need Omarchy 4 (the Quickshell bar) plus `gpu-screen-recorder`, `gsr-cli`, and `ffmpeg`. Omarchy already installs those. Opening the last clip in Omacut needs the `omacut` package, which new Omarchy Quattro installs include.

Plugin id: `io.github.anthonyposchen.instant-replay`.

## Everyday use

Left-click the disc in the bar to open Settings. The switch in the top-right turns the buffer on and off.

| Action | What it does |
| --- | --- |
| Left-click the disc | Open or close Settings. |
| Right-click the disc | Save the last N seconds to a video file, while the buffer is recording. |
| Middle-click the disc | Refresh status. |

The disc is theme-colored when the buffer is off or waiting for a window, red while it is capturing, and three dots while a clip is encoding.

Settings status is one of:

- **RECORDING** — the buffer is capturing right now.
- **WAITING** — the switch is on, but Follow Allowlist has no listed window yet, so nothing is being captured.
- **DISABLED** — the buffer is off.

**Save clip** writes a file. **Open clips** opens the folder. After a save, Settings shows that path with a copy icon (clipboard) and the Omacut icon (opens the file in Omacut to trim). Saving does not stop the buffer.

Clips land in `~/Videos/Replays` (or `$OMARCHY_SCREENRECORD_DIR/Replays`) unless you pick another folder under Replay.

Encoding a clip can use spare CPU. The job runs at nice 19 with idle I/O so a game keeps the cores. Wait it out, or lower clip resolution.

## What you capture

The slice of screen in the buffer is **Recording region**. Open that section in Settings and pick a **Mode**. The rest of that section changes to match.

### Monitor

The whole display. Default for a new install.

Pick a named output (`DP-1`, `HDMI-A-1`, …) or leave it empty to use whichever monitor is focused when you turn the buffer on. Moving the mouse to another screen later does not retarget.

Use this when you want “whatever is on this monitor.” It has no per-window audio option. The clip is the full output.

### Follow focused window

The buffer tracks the window you are using, among the windows you allow.

The focused window that passes the Filter is what Save crops to. A fullscreen game is the same as the monitor. Alt-tab to Discord does not yank the buffer onto Discord. If that game moves to another monitor, Save still writes one file: the old screen and the new screen are joined in private.

When the game closes, the buffer stays on that monitor for one Replay Window (so you can still save the last seconds of that window). After that:

- **Allowlist** waits until a listed window is open again. It does not silently capture the whole monitor.
- **All** and **Denylist** stay capturing that monitor until a matching window returns, or you turn the switch off.

Follow has a **Filter**:

| Filter | Who can become the tracked window |
| --- | --- |
| **All** | Any window except built-in Omarchy chrome (bar, launcher, lock). Emptying Denylist is not the same as All. |
| **Allowlist** | Only classes you pick. Click **Pick window** on each game. If several listed games are open and none is focused, list order wins. If none of those windows exist, status is **WAITING** and nothing is captured. Switching back to Allowlist with no listed window waits immediately. |
| **Denylist** | Skip classes you pick. Ships with Omarchy chrome; you can remove those. It does not hunt for “any open game.” If Discord is focused when you turn it on, it captures that monitor until you focus something that is not on the list. |

Use Follow when you bounce between a game and chat and still want the buffer on the game. Pair it with Window audio if the clip should hear the game, not Discord.

### Window

One specific window, from **Pick window**. Looking at anything else does not retarget.

If you turn the switch on with nothing picked yet, it pins the focused window (not the Omarchy bar). If only chrome is focused, Enable fails until you pick a window.

Switching to Window while already capturing keeps the buffer running on that pin. If the pinned window moves to another monitor, Save still writes one file.

Use this when you only ever care about one client (a game, a stream layout) and do not want Follow’s filter.

### Custom

A rectangle you draw on one monitor. Re-picking while capturing starts a new buffer on the new rectangle; Save still writes one file if both pieces fall inside the Replay Window.

Use this for a fixed slice of a screen. For a fullscreen window, use Window or Follow instead.

## How long, and how the file looks

These live under **Replay**.

**Replay Window** is how much recent time Save keeps: 15 seconds to 2 hours, default 60 seconds. Right-click save uses that length. You can still ask the helper for a shorter save (for example 30 seconds) without changing the setting.

**Resolution** is the size of the saved file, not the size of the monitor: 720p, 1080p (default), 1440p, or 2160p.

**Layout** is how captured frames land on that canvas:

- **Fit** (default) — show the whole picture, add bars if the aspect ratio differs.
- **Stretch** — fill the canvas, may distort.
- **Center** — keep native pixels; bars if smaller, crop if larger.

Changing resolution or layout does not restart the buffer. **Cursor** includes the pointer in the buffer; it lives in Replay, not Encoder.

**Encoder** (codec, FPS, quality, framerate mode, bitrate mode) is for people who want to change how GPU Screen Recorder compresses. Collapsed by default. H.264 cannot capture a side longer than 4096 pixels on NVENC. A 5120×1440 output with codec `h264` falls back to HEVC so capture can start. Prefer `auto` or `hevc` on ultrawide.

Changing mode, which monitor or rectangle you capture, Replay Window length, audio, or encoder settings while Recording restarts the buffer on the new target. Recent history from the old target is kept and joined on Save when it still falls inside the Replay Window.

## What the clip hears

Audio is under **Replay**.

| Setting | What the saved file hears |
| --- | --- |
| No audio | Video only. |
| Desktop audio | Whatever the system is playing. Default. |
| Desktop + microphone | System output mixed with the default input. |
| Window audio | Only the tracked window’s application stream. Follow and Window modes. |
| Window + microphone | That stream plus the default input. Follow and Window modes. |

Window audio is the app’s PipeWire name, not the Hyprland class. Java games (RuneLite and similar) often show up as `PipeWire ALSA [java]`. Discord’s window-share picker can still miss that stream. This plugin cannot inject audio into Discord.

Monitor and Custom have no Window audio option. Changing audio while Recording restarts the buffer.

## Set this up for a game

Goal: the buffer stays on the game you are looking at, and the clip hears that game, not the rest of the desktop.

1. Left-click the bar icon.
2. Open **Recording region**. Set **Mode** to Follow focused window.
3. Set **Filter** to Allowlist if you only want listed games, or Denylist if you want “anything except chat and chrome.” Use **Pick window** to add entries. Allowlist list order is the fallback when none of those games is focused.
4. Open **Replay**. Set **Audio** to Window audio (or Window + microphone). Leave Desktop audio if you want the whole system mix.
5. Turn the switch on with the game focused. Status should be **RECORDING**. If you chose Allowlist and the game is not open, status is **WAITING** until that window exists.

You can instead set Mode to **Window** and pick the game once. That is simpler if you never want Follow to retarget.

## Settings map

Left-click the disc. The switch is top-right.

On the main surface: Save clip, Open clips, and last-save path (copy + Omacut) once you have saved at least once.

Then three collapsed groups, in this order. An open group ends with a divider.

| Section | What it holds |
| --- | --- |
| **Replay** | Output folder, Replay Window, audio, resolution, layout, cursor, Copy Hyprland keybinds. |
| **Recording region** | Mode, Filter, Allowlist or Blacklist, monitor / pick window / pick region. |
| **Encoder** | Codec, FPS, quality, framerate mode, bitrate mode. |

A new install starts enabled. The last on/off/waiting state is restored when the shell loads. Turn the top-right switch off if you want it to stay off.

Allowlist, Blacklist, and the pinned window apply while Recording. Changing mode, monitor, rectangle, Replay Window, audio, or encoder restarts the buffer. Cursor, clip resolution, and layout do not.

```sh
omarchy bar set io.github.anthonyposchen.instant-replay seconds 120 --json
omarchy bar set io.github.anthonyposchen.instant-replay audio desktop --json
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `mode` | `monitor` | `monitor`, `follow`, `pin`, or `region`. Labels: Monitor, Follow focused window, Window, Custom. |
| `monitor` | empty | Output name. Empty uses the focused monitor at start. |
| `seconds` | `60` | Replay Window, 15–7200. |
| `audio` | `desktop` | `none`, `desktop`, `both`. Follow and Window also offer `window` and `window-mic`. |
| `filter` | `all` | Follow only: `all`, `allowlist`, `denylist`. |
| `matchList` | empty | Allowlist window classes, comma-separated. |
| `blacklist` | Omarchy chrome | Denylist window classes. |
| `pinAddress` | empty | Hyprland client address for Window mode. |
| `region` | empty | Custom rectangle, `WxH+X+Y`. |
| `clipResolution` | `1080p` | Clip canvas. |
| `clipScale` | `fit` | `fit`, `stretch`, or `center`. |
| `codec` | `auto` | `auto`, `h264`, `hevc`, `av1`, `vp8`, `vp9`. |
| `fps` | `60` | Capture frame rate. |
| `quality` | `40000` | Encoder quality / bitrate knob. |
| `cursor` | `true` | Include the pointer. In Replay, not Encoder. |
| `framerateMode` | `cfr` | `cfr` or `vfr`. |
| `bitrateMode` | `cbr` | `cbr` or `vbr`. |
| `outputDir` | empty | Absolute path for clips. Empty uses Videos/Replays. |

## Hotkeys

The plugin cannot write your Hyprland bind file. In Replay, use **Copy Hyprland keybinds**, or paste this next to your other `bindd` lines. Save is ready to use. The rest stay commented until you want them.

```hyprlang
bindd = SUPER ALT, R, Save replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay save
# bindd = SUPER ALT, S, Start replay buffer, exec, omarchy-shell io.github.anthonyposchen.instant-replay start
# bindd = SUPER ALT, X, Stop replay buffer, exec, omarchy-shell io.github.anthonyposchen.instant-replay stop
# bindd = SUPER ALT, T, Toggle Instant Replay panel, exec, omarchy-shell io.github.anthonyposchen.instant-replay toggle
# bindd = SUPER ALT, O, Open Instant Replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay open
# bindd = SUPER ALT, C, Close Instant Replay, exec, omarchy-shell io.github.anthonyposchen.instant-replay close
```

`show`, `hide`, and `refresh` are not in that list.

## This is not Omarchy screen record

Alt+Print and `omarchy screenrecord` are a separate start/stop take. Instant Replay starts GPU Screen Recorder as `omarchy-instant-replay-gsr` so the stock indicator should not treat the buffer as that take.

Only one screen capture can run at a time. While Instant Replay is recording, `omarchy screenrecord` may fail to start. Turn Instant Replay off first if you want a stock take. Instant Replay never stops a stock recording to start itself.

## Helper

After install:

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

## Files

| Path | What it is |
| --- | --- |
| `~/.config/omarchy-instant-replay/config` | Helper settings. |
| `~/.local/state/omarchy-instant-replay/` | Activity, PID, segments, save jobs, GSR log. |
| `$XDG_RUNTIME_DIR/omarchy-instant-replay/` | IPC socket and GSR output. Gone on logout. |
| `~/Videos/Replays/` (or your clips folder) | Saved clips. Kept after plugin removal. |

An older `~/.config/omarchy-shadowplay/` config is copied once if the new config file is missing.

## If something fails

**Capture will not start.** Only one screen capture can run. Stop `omarchy screenrecord` first. If the log says H.264 max resolution, use `auto` or `hevc`.

**Settings says WAITING.** Follow Allowlist is on and no listed window is open. Nothing is being captured. Open a listed game, or change Filter.

**Window audio is silent.** The Hyprland class is not the PipeWire name. Java titles (RuneLite) are often `PipeWire ALSA [java]`. Check `"$helper" status --json` shows the right window, then Save again.

**A clip is encoding and the machine feels busy.** The bar shows three dots. ffmpeg is niced; it still uses spare cores. Wait, or lower clip resolution.

**The bar icon did not update after you edited QML.** The shell loads `~/.config/omarchy/plugins/io.github.anthonyposchen.instant-replay/`, not a git checkout. Copy into that directory and run `omarchy restart shell`.

The GPU Screen Recorder log is `~/.local/state/omarchy-instant-replay/gsr.log`.

## Remove

```sh
omarchy plugin remove io.github.anthonyposchen.instant-replay
```

That removes the plugin from the bar. It does not stop a buffer that is still recording. Run `"$helper" stop` first, or reboot.

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
