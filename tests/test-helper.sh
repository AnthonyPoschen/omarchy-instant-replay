#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$root/bin/omarchy-shadowplay"
fake_gsr="$root/tests/fake-gsr"
fake_cli="$root/tests/fake-gsr-cli"

chmod +x "$helper" "$fake_gsr" "$fake_cli"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export HOME="$work/home"
export XDG_CONFIG_HOME="$work/config"
export XDG_STATE_HOME="$work/state"
export XDG_RUNTIME_DIR="$work/runtime"
export XDG_VIDEOS_DIR="$work/videos"
export SHADOWPLAY_FAKE_DIR="$work/fake"
export SHADOWPLAY_GSR_BIN="$fake_gsr"
export SHADOWPLAY_GSR_CLI_BIN="$fake_cli"
export SHADOWPLAY_FOCUSED_MONITOR="DP-1"
export SHADOWPLAY_NOTIFY=false

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$XDG_VIDEOS_DIR" "$SHADOWPLAY_FAKE_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1" needle="$2"
  grep -F -- "$needle" "$file" >/dev/null || fail "$file did not contain: $needle"
}

"$helper" start >/dev/null
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "start did not launch the recorder"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-w"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "DP-1"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-r"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "60"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-a"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "default_output"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-ipc"

status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .monitor == "DP-1" and .seconds == 60 and .audio == "desktop"' >/dev/null \
  || fail "status json after start: $status"
echo "$status" | jq -e '.mode == "monitor" and .filter == "all" and .captureExtent == "monitor" and (.matchList | length) == 0 and (.blacklist | length) == 0' >/dev/null \
  || fail "status json missing mode defaults: $status"
echo "$status" | jq -e '.encoder.codec == "auto" and .encoder.fps == 60 and .encoder.quality == 40000 and .encoder.cursor == true and .encoder.framerateMode == "cfr" and .encoder.bitrateMode == "cbr"' >/dev/null \
  || fail "status json missing encoder knobs: $status"

clip=$("$helper" save)
[[ $clip == "$SHADOWPLAY_FAKE_DIR/replay.mp4" ]] || fail "save returned $clip"
[[ ! -e $SHADOWPLAY_FAKE_DIR/saved-seconds ]] || fail "default save should not pass a seconds override"

clip=$("$helper" save 30)
[[ -e $SHADOWPLAY_FAKE_DIR/saved-seconds ]] || fail "save 30 did not record seconds"
[[ $(<"$SHADOWPLAY_FAKE_DIR/saved-seconds") == 30 ]] || fail "save 30 stored the wrong duration"

"$helper" stop
[[ ! -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "stop left the recorder running"
status=$("$helper" status --json)
echo "$status" | jq -e '.running == false' >/dev/null || fail "status json after stop: $status"

"$helper" start --monitor=HDMI-A-1 --seconds=120 --audio=none >/dev/null
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "HDMI-A-1"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "120"
if grep -F -- "-a" "$SHADOWPLAY_FAKE_DIR/gsr.args" >/dev/null; then
  fail "audio=none should not pass -a"
fi
status=$("$helper" status --json)
echo "$status" | jq -e '.monitor == "HDMI-A-1" and .seconds == 120 and .audio == "none"' >/dev/null \
  || fail "status after retargeted start: $status"
"$helper" stop

if "$helper" start --monitor=NOPE >/dev/null 2>"$work/err"; then
  fail "start accepted a missing monitor"
fi
grep -q 'not available' "$work/err" || fail "missing monitor error was unclear: $(<"$work/err")"

monitors=$("$helper" monitors --json)
echo "$monitors" | jq -e '.[0].name == "HDMI-A-1" and .[1].name == "DP-1" and .[1].focused == true' >/dev/null \
  || fail "monitors json: $monitors"

settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.mode == "monitor" and .filter == "all" and .captureExtent == "monitor" and (.matchList | type) == "array" and (.blacklist | type) == "array"' >/dev/null \
  || fail "settings json defaults: $settings"
echo "$settings" | jq -e '.encoder.codec == "auto" and .encoder.fps == 60' >/dev/null \
  || fail "settings json encoder: $settings"

# v0.1 config without the new keys still starts one monitor replay buffer.
"$helper" stop >/dev/null 2>&1 || true
mkdir -p "$XDG_CONFIG_HOME/omarchy-shadowplay"
printf 'monitor=\nseconds=60\naudio=desktop\n' > "$XDG_CONFIG_HOME/omarchy-shadowplay/config"
"$helper" start >/dev/null
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-w"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "DP-1"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-r"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "60"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-f"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "60"
if grep -F -- "-cursor" "$SHADOWPLAY_FAKE_DIR/gsr.args" >/dev/null; then
  fail "default cursor should omit -cursor"
fi
status=$("$helper" status --json)
echo "$status" | jq -e '.mode == "monitor" and .running == true and .seconds == 60' >/dev/null \
  || fail "omitted keys should still default Monitor Mode: $status"
"$helper" stop

echo OK
