# Contributing

Instant Replay is an Omarchy 4 Quickshell plugin. The installable id is
`io.github.anthonyposchen.instant-replay`. Source is
[AnthonyPoschen/omarchy-instant-replay](https://github.com/AnthonyPoschen/omarchy-instant-replay).

Product language is in [`CONTEXT.md`](../CONTEXT.md). Recorded design
choices are in [`adr/`](adr/).

## Layout

- `bin/omarchy-instant-replay` owns GPU Screen Recorder lifecycle, IPC, and
  config under XDG. QML does not construct `gpu-screen-recorder` argv.
- `BarWidget.qml` is the bar icon and IPC target.
- `Panel.qml` is the popup.
- `Model.js` parses helper JSON only.

## Capture constraints

Replay is monitor-scoped or a persisted Custom rectangle on one monitor.
Portal window capture is out of scope until a start failure has an
explicit fallback. Re-picking a region while the buffer is live is a Split.

Launch the recorder as argv0 `omarchy-instant-replay-gsr` so Omarchy's
`pgrep -f '^gpu-screen-recorder'` session recorder does not stop this
process. Only one KMS capture can run at a time.

## Test on a live Omarchy shell

The running shell loads
`~/.config/omarchy/plugins/io.github.anthonyposchen.instant-replay/`,
not a git checkout. After changing QML, JS, or `bin/omarchy-instant-replay`,
copy those files into that directory, then:

```sh
rm -rf ~/.cache/quickshell
omarchy restart shell
```

## Tests

`tests/test-helper.sh` covers start, save, stop, and monitor selection. It
uses the fakes in `tests/`. Those tests do not call a real GPU encoder.

```sh
bash tests/test-helper.sh
```

## Issues

Bugs and ideas are tracked at
<https://github.com/AnthonyPoschen/omarchy-instant-replay/issues>.
