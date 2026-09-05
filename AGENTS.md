# Agent notes

This is an Omarchy 4 Quickshell plugin. The installable id is
`io.github.anthonyposchen.shadowplay`. The GitHub repository name is
`omarchy-shadowplay`.

## Layout

- `bin/omarchy-shadowplay` owns GPU Screen Recorder lifecycle, IPC, and
  config under XDG. QML must not construct `gpu-screen-recorder` argv.
- `BarWidget.qml` is the bar icon and IPC target.
- `Panel.qml` is the popup.
- `Model.js` parses helper JSON only.

## Capture rules

v0.1 is monitor-scoped replay. Do not add region or portal window capture
until the helper can retarget without surprising buffer loss, and until
portal start failures have an explicit fallback.

Launch the recorder as argv0 `omarchy-shadowplay-gsr` so Omarchy's
`pgrep -f '^gpu-screen-recorder'` session recorder does not stop this
process. Still assume only one KMS capture can run at a time.

## Tests

`tests/test-helper.sh` is the contract for start/save/stop/monitor
selection. It uses the fakes in `tests/`. Do not call a real GPU encoder
from unit tests.
