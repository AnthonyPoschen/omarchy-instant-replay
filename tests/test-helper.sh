#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$root/bin/omarchy-shadowplay"
fake_gsr="$root/tests/fake-gsr"
fake_cli="$root/tests/fake-gsr-cli"
fake_ffmpeg="$root/tests/fake-ffmpeg"

chmod +x "$helper" "$fake_gsr" "$fake_cli" "$fake_ffmpeg"

work=$(mktemp -d)
session_pid=""
trap 'rm -rf "$work"; if [[ -n ${session_pid:-} ]]; then kill "$session_pid" 2>/dev/null || true; wait "$session_pid" 2>/dev/null || true; fi' EXIT

export HOME="$work/home"
export XDG_CONFIG_HOME="$work/config"
export XDG_STATE_HOME="$work/state"
export XDG_RUNTIME_DIR="$work/runtime"
export XDG_VIDEOS_DIR="$work/videos"
export SHADOWPLAY_FAKE_DIR="$work/fake"
export SHADOWPLAY_GSR_BIN="$fake_gsr"
export SHADOWPLAY_GSR_CLI_BIN="$fake_cli"
export SHADOWPLAY_FFMPEG_BIN="$fake_ffmpeg"
export SHADOWPLAY_FOCUSED_MONITOR="DP-1"
export SHADOWPLAY_NOTIFY=false
export SHADOWPLAY_NOW=800

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

grep -F "exec -a omarchy-shadowplay-gsr" "$helper" >/dev/null \
  || fail "helper must launch the recorder as omarchy-shadowplay-gsr"

replay_dir="$XDG_VIDEOS_DIR/Replays"
segment_index="$XDG_STATE_HOME/omarchy-shadowplay/segments/index"

public_clips() {
  find "$replay_dir" -maxdepth 1 -type f -name '*.mp4' 2>/dev/null | sort
}

assert_no_gsr_leftovers() {
  local leftovers
  leftovers=$(find "$SHADOWPLAY_FAKE_DIR" -maxdepth 1 -type f -name 'gsr-save-*.mp4' 2>/dev/null || true)
  [[ -z $leftovers ]] || fail "save-replay leftovers in public/fake dir: $leftovers"
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
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "$XDG_RUNTIME_DIR/omarchy-shadowplay/gsr-output"

status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .monitor == "DP-1" and .seconds == 60 and .audio == "desktop"' >/dev/null \
  || fail "status json after start: $status"
echo "$status" | jq -e '.mode == "monitor" and .filter == "all" and .captureExtent == "monitor" and (.matchList | length) == 0 and (.blacklist | length) == 0' >/dev/null \
  || fail "status json missing mode defaults: $status"
echo "$status" | jq -e '.encoder.codec == "auto" and .encoder.fps == 60 and .encoder.quality == 40000 and .encoder.cursor == true and .encoder.framerateMode == "cfr" and .encoder.bitrateMode == "cbr"' >/dev/null \
  || fail "status json missing encoder knobs: $status"

clip=$("$helper" save)
[[ $clip == "$replay_dir/Replay-800.mp4" ]] || fail "save returned $clip"
[[ -e $clip ]] || fail "Clip was not written"
[[ ! -e $SHADOWPLAY_FAKE_DIR/saved-seconds ]] || fail "default save should not pass a seconds override"
[[ ! -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "save without a Split should not stitch"
[[ $(public_clips) == "$clip" ]] || fail "Replays should contain only the Clip: $(public_clips)"
assert_no_gsr_leftovers

export SHADOWPLAY_NOW=801
clip=$("$helper" save 30)
[[ -e $SHADOWPLAY_FAKE_DIR/saved-seconds ]] || fail "save 30 did not record seconds"
[[ $(<"$SHADOWPLAY_FAKE_DIR/saved-seconds") == 30 ]] || fail "save 30 stored the wrong duration"
[[ $clip == "$replay_dir/Replay-801.mp4" ]] || fail "save 30 returned $clip"
assert_no_gsr_leftovers

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

# Busy KMS: a stock session recorder owns capture. Start must fail without signaling it.
rm -f "$SHADOWPLAY_FAKE_DIR/session.killed" "$SHADOWPLAY_FAKE_DIR/running"
setsid bash -c '
  trap "echo killed > \"$SHADOWPLAY_FAKE_DIR/session.killed\"; exit 1" INT TERM
  echo $$ > "$SHADOWPLAY_FAKE_DIR/session.pid"
  echo $$ > "$SHADOWPLAY_FAKE_DIR/session-recording"
  exec -a gpu-screen-recorder sleep 30
' &
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -r $SHADOWPLAY_FAKE_DIR/session.pid ]] && break
  sleep 0.05
done
[[ -r $SHADOWPLAY_FAKE_DIR/session.pid ]] || fail "session recorder fake did not start"
session_pid=$(<"$SHADOWPLAY_FAKE_DIR/session.pid")
kill -0 "$session_pid" 2>/dev/null || fail "session recorder pid is not alive"

if "$helper" start >/dev/null 2>"$work/busy-err"; then
  fail "start succeeded while a Session Recording was running"
fi
grep -qiE 'busy|Session Recording' "$work/busy-err" || fail "busy error was unclear: $(<"$work/busy-err")"
[[ ! -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "start launched the replay buffer while KMS was busy"
[[ ! -e $SHADOWPLAY_FAKE_DIR/session.killed ]] || fail "start signaled the stock session recorder"
kill -0 "$session_pid" 2>/dev/null || fail "stock session recorder was killed"
if grep -E 'pkill|killall' "$helper" | grep -q 'gpu-screen-recorder'; then
  fail "helper must not pkill/killall gpu-screen-recorder"
fi

kill "$session_pid" 2>/dev/null || true
wait "$session_pid" 2>/dev/null || true
session_pid=""
rm -f "$SHADOWPLAY_FAKE_DIR/session-recording" "$SHADOWPLAY_FAKE_DIR/session.pid" "$SHADOWPLAY_FAKE_DIR/session.killed"

rm -rf "$replay_dir"
export SHADOWPLAY_NOW=1000
"$helper" start --monitor=DP-1 --seconds=60 --audio=desktop >/dev/null
before=$(public_clips || true)
"$helper" start --monitor=HDMI-A-1 >/dev/null
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "Split left capture stopped"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "HDMI-A-1"
[[ -r $segment_index ]] || fail "Split did not keep a Segment"
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 1 ]] || fail "expected 1 Segment after first Split, got $segment_count"
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .monitor == "HDMI-A-1"' >/dev/null \
  || fail "status after Split: $status"
[[ $(public_clips || true) == "$before" ]] || fail "Split leaked a file into Replays"
assert_no_gsr_leftovers

clip=$("$helper" save)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "Save after Split did not join Segments"
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 2 ]] || fail "Save after Split should join 1 Segment + live"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "-filter_complex"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "scale=5120:1440"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "concat=n=2:v=1:a=1"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "-c:a"
if grep -Fq -- "-c copy" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"; then
  fail "join used stream copy instead of re-encoding"
fi
if grep -Fxq -- "-an" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"; then
  fail "Save after Split stripped audio from a desktop Replay Buffer"
fi
[[ $clip == "$replay_dir/Replay-1000.mp4" ]] || fail "joined Clip path was $clip"
[[ -e $clip ]] || fail "joined Clip was not written"
[[ $(public_clips) == "$clip" ]] || fail "Replays should contain only the joined Clip: $(public_clips)"
assert_no_gsr_leftovers

"$helper" start --monitor=DP-1 >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 2 ]] || fail "A→B→A should keep both overlapping Segments, got $segment_count"
[[ $(public_clips) == "$clip" ]] || fail "bounce Split leaked into Replays"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list"
export SHADOWPLAY_NOW=1001
clip=$("$helper" save)
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 3 ]] || fail "bounce Save should join both Segments + live"
[[ $clip == "$replay_dir/Replay-1001.mp4" ]] || fail "bounce Clip path was $clip"
[[ $(public_clips | wc -l) == 2 ]] || fail "expected two public Clips after two Saves, got $(public_clips)"
assert_no_gsr_leftovers

"$helper" settings set monitor HDMI-A-1 >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 3 ]] || fail "live settings Split should flush another Segment, got $segment_count"
assert_no_gsr_leftovers

export SHADOWPLAY_NOW=1100
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list"
clip=$("$helper" save)
[[ ! -r $segment_index ]] || fail "Segments older than the Replay Window were kept"
[[ ! -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "expired Segments should not be stitched"
[[ $clip == "$replay_dir/Replay-1100.mp4" ]] || fail "Save after discard should be one Clip, got $clip"
[[ -e $clip ]] || fail "discard Clip was not written"
assert_no_gsr_leftovers

"$helper" stop
echo OK
