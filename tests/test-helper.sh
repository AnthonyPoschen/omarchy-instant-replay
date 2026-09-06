#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$root/bin/omarchy-instant-replay"
fake_gsr="$root/tests/fake-gsr"
fake_cli="$root/tests/fake-gsr-cli"
fake_ffmpeg="$root/tests/fake-ffmpeg"
fake_slurp="$root/tests/fake-slurp"
fake_window="$root/tests/fake-window-picker"

chmod +x "$helper" "$fake_gsr" "$fake_cli" "$fake_ffmpeg" "$fake_slurp" "$fake_window"

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

wait_for_clip() {
  local path="$1" i
  for i in $(seq 1 80); do
    [[ -e $path ]] && return 0
    sleep 0.05
  done
  fail "Clip was not written: $path"
}

wait_for_saves() {
  local i status n
  for i in $(seq 1 80); do
    status=$("$helper" status --json)
    n=$(echo "$status" | jq -r '.saving // 0')
    [[ $n == 0 ]] && return 0
    sleep 0.05
  done
  fail "save jobs still running: $status"
}

saved() {
  local clip
  clip=$("$helper" save "$@")
  [[ -n $clip ]] || fail "save printed no path"
  wait_for_clip "$clip"
  wait_for_saves
  printf '%s\n' "$clip"
}

assert_file_contains() {
  local file="$1" needle="$2"
  grep -F -- "$needle" "$file" >/dev/null || fail "$file did not contain: $needle"
}

grep -F "exec -a omarchy-instant-replay-gsr" "$helper" >/dev/null \
  || fail "helper must launch the recorder as omarchy-instant-replay-gsr"
grep -F "omarchy-capture-region" "$helper" >/dev/null \
  || fail "helper must use Omarchy's region picker"
grep -F "omarchy-menu-select" "$helper" >/dev/null \
  || fail "helper must use Omarchy's window picker"

replay_dir="$XDG_VIDEOS_DIR/Replays"
segment_index="$XDG_STATE_HOME/omarchy-instant-replay/segments/index"

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
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-c"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "mp4"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-f"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "60"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-k"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "auto"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-q"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "40000"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-fm"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "cfr"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-bm"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "cbr"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-a"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "default_output"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-ipc"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "$XDG_RUNTIME_DIR/omarchy-instant-replay/gsr-output"

status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .monitor == "DP-1" and .seconds == 60 and .audio == "desktop" and .saving == 0' >/dev/null \
  || fail "status json after start: $status"
echo "$status" | jq -e '.mode == "monitor" and .filter == "all" and .captureExtent == "monitor" and .clipResolution == "1080p" and .clipScale == "fit" and (.matchList | length) == 0 and (.blacklist | length) == 3' >/dev/null \
  || fail "status json missing mode defaults: $status"
echo "$status" | jq -e '.blacklist == ["waybar","walker","hyprlock"]' >/dev/null   || fail "new install blacklist should be Omarchy chrome: $status"
echo "$status" | jq -e '.encoder.codec == "auto" and .encoder.fps == 60 and .encoder.quality == 40000 and .encoder.cursor == true and .encoder.framerateMode == "cfr" and .encoder.bitrateMode == "cbr"' >/dev/null \
  || fail "status json missing encoder knobs: $status"

clip=$(saved)
[[ $clip == "$replay_dir/Replay-800.mp4" ]] || fail "save returned $clip"
[[ -e $clip ]] || fail "Clip was not written"
[[ ! -e $SHADOWPLAY_FAKE_DIR/saved-seconds ]] || fail "default save should not pass a seconds override"
[[ -e $SHADOWPLAY_FAKE_DIR/ffmpeg.args ]] || fail "Save should fit the Clip to 1080p"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "scale=1920:1080:force_original_aspect_ratio=decrease"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 1 ]] || fail "save without a Split should be one input, got $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list")"
if grep -F "concat=n=" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" >/dev/null; then
  fail "save without a Split should not concat Segments"
fi
[[ $(<"$SHADOWPLAY_FAKE_DIR/restart-replay") == true ]] || fail "Save should restart the Replay Buffer"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "Save stopped capture"
[[ $(public_clips) == "$clip" ]] || fail "Replays should contain only the Clip: $(public_clips)"
assert_no_gsr_leftovers

export SHADOWPLAY_NOW=801
clip=$(saved 30)
[[ -e $SHADOWPLAY_FAKE_DIR/saved-seconds ]] || fail "save 30 did not record seconds"
[[ $(<"$SHADOWPLAY_FAKE_DIR/saved-seconds") == 30 ]] || fail "save 30 stored the wrong duration"
[[ $clip == "$replay_dir/Replay-801.mp4" ]] || fail "save 30 returned $clip"
assert_no_gsr_leftovers

export SHADOWPLAY_NOW=802
"$helper" start --monitor=HDMI-A-1 >/dev/null
export SHADOWPLAY_FFMPEG_HOLD="$work/ffmpeg-hold"
: > "$SHADOWPLAY_FFMPEG_HOLD"
"$helper" save >/dev/null &
save_pid1=$!
"$helper" save >/dev/null &
save_pid2=$!
for i in $(seq 1 40); do
  status=$("$helper" status --json)
  n=$(echo "$status" | jq -r '.saving // 0')
  running_ff=0
  [[ -r $SHADOWPLAY_FAKE_DIR/ffmpeg.running ]] && running_ff=$(<"$SHADOWPLAY_FAKE_DIR/ffmpeg.running")
  if [[ $n == 2 ]] || [[ ${running_ff:-0} == 2 ]]; then
    break
  fi
  sleep 0.05
done
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .saving >= 1' >/dev/null \
  || fail "parallel Save should keep the buffer Live and show saving: $status"
n=$(echo "$status" | jq -r '.saving')
(( n >= 1 && n <= 2 )) || fail "expected 1-2 in-flight saves, got $n from $status"
rm -f "$SHADOWPLAY_FFMPEG_HOLD"
wait "$save_pid1" "$save_pid2"
wait_for_saves
status=$("$helper" status --json)
echo "$status" | jq -e '.saving == 0' >/dev/null || fail "saving count should clear: $status"
[[ $(public_clips | wc -l) == 4 ]] || fail "two parallel Saves should add two Clips, got $(public_clips)"
assert_no_gsr_leftovers
unset SHADOWPLAY_FFMPEG_HOLD

"$helper" stop
[[ ! -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "stop left the recorder running"
status=$("$helper" status --json)
echo "$status" | jq -e '.running == false' >/dev/null || fail "status json after stop: $status"
echo "$status" | jq -e '.phase == "off"' >/dev/null || fail "stop should be Off, not lingering capture: $status"

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

"$helper" settings set seconds 7200 >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.seconds == 7200' >/dev/null || fail "2 hour replay window rejected: $settings"
if "$helper" settings set seconds 7201 >/dev/null 2>"$work/sec-err"; then
  fail "seconds above 2 hours was accepted"
fi
grep -q 'between' "$work/sec-err" || fail "over-max seconds error was unclear: $(<"$work/sec-err")"
"$helper" settings set seconds 60 >/dev/null

# v0.1 config without the new keys still starts one monitor replay buffer.
"$helper" stop >/dev/null 2>&1 || true
mkdir -p "$XDG_CONFIG_HOME/omarchy-instant-replay"
printf 'monitor=\nseconds=60\naudio=desktop\n' > "$XDG_CONFIG_HOME/omarchy-instant-replay/config"
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.blacklist == ["waybar","walker","hyprlock"]' >/dev/null \
  || fail "omitted blacklist key should seed Omarchy chrome: $settings"
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

"$helper" settings set outputDir "$work/custom-replays" >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e --arg d "$work/custom-replays" '.outputDir == $d' >/dev/null \
  || fail "custom clips folder was not stored: $settings"
if "$helper" settings set outputDir "relative/replays" >/dev/null 2>"$work/outdir-err"; then
  fail "relative outputDir was accepted"
fi
export SHADOWPLAY_NOW=5000
"$helper" start --monitor=DP-1 --seconds=60 --audio=desktop >/dev/null
clip=$(saved)
[[ $clip == "$work/custom-replays/Replay-5000.mp4" ]] || fail "custom clips folder save was $clip"
[[ -e $clip ]] || fail "custom clips folder Clip was not written"
"$helper" settings set outputDir "" >/dev/null
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

clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "Save after Split did not join Segments"
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 2 ]] || fail "Save after Split should join 1 Segment + live"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "-filter_complex"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "scale=1920:1080:force_original_aspect_ratio=decrease"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
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
[[ $(<"$SHADOWPLAY_FAKE_DIR/restart-replay") == true ]] || fail "Save after Split should restart the Replay Buffer"
[[ ! -r $segment_index ]] || fail "Save should consume joined Segments"
assert_no_gsr_leftovers

rm -f "$SHADOWPLAY_FAKE_DIR/concat.list"
export SHADOWPLAY_NOW=1001
clip=$(saved)
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 1 ]] || fail "second Save should not re-join consumed Segments"
[[ $clip == "$replay_dir/Replay-1001.mp4" ]] || fail "second Clip path was $clip"
[[ $(public_clips | wc -l) == 2 ]] || fail "expected two public Clips after two Saves, got $(public_clips)"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "second Save stopped capture"
assert_no_gsr_leftovers

"$helper" start --monitor=DP-1 >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 1 ]] || fail "Split after Save should keep only new history, got $segment_count"
[[ $(public_clips | wc -l) == 2 ]] || fail "bounce Split leaked into Replays"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list"
export SHADOWPLAY_NOW=1002
clip=$(saved)
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 2 ]] || fail "Split after Save should join 1 new Segment + live"
[[ $clip == "$replay_dir/Replay-1002.mp4" ]] || fail "bounce Clip path was $clip"
[[ $(public_clips | wc -l) == 3 ]] || fail "expected three public Clips after three Saves, got $(public_clips)"
assert_no_gsr_leftovers

"$helper" settings set monitor HDMI-A-1 >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 1 ]] || fail "live settings Split should flush another Segment, got $segment_count"
assert_no_gsr_leftovers

"$helper" settings set fps 30 >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 2 ]] || fail "encoder settings should Split while Live, got $segment_count"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "30"
"$helper" settings set codec hevc >/dev/null
"$helper" settings set quality 20000 >/dev/null
"$helper" settings set cursor false >/dev/null
"$helper" settings set framerateMode vfr >/dev/null
"$helper" settings set bitrateMode vbr >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 7 ]] || fail "each encoder knob should Split while Live, got $segment_count"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-k"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "hevc"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "20000"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-cursor"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "no"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "vfr"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "vbr"
"$helper" settings set filter allowlist >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 7 ]] || fail "filter should not Split, got $segment_count"
"$helper" settings set clipResolution 720p >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 7 ]] || fail "Clip resolution should not Split, got $segment_count"
"$helper" settings set clipScale stretch >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 7 ]] || fail "Clip layout should not Split, got $segment_count"
"$helper" settings set clipScale fit >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.clipResolution == "720p" and .clipScale == "fit"' >/dev/null || fail "clip layout settings: $settings"
rm -f "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "scale=1280:720:force_original_aspect_ratio=decrease"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "pad=1280:720:(ow-iw)/2:(oh-ih)/2"
"$helper" settings set clipResolution 1080p >/dev/null
"$helper" settings set clipScale stretch >/dev/null
rm -f "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "scale=1920:1080,setsar=1"
if grep -F "force_original_aspect_ratio=" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" >/dev/null; then
  fail "stretch should distort instead of fit/fill"
fi
"$helper" settings set clipScale center >/dev/null
rm -f "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
grep -E 'crop=min\(iw\\?,1920\):min\(ih\\?,1080\)' "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" >/dev/null \
  || fail "center native should crop overflow: $(<"$SHADOWPLAY_FAKE_DIR/ffmpeg.args")"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
if grep -F "force_original_aspect_ratio=" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" >/dev/null; then
  fail "center native should not scale"
fi
"$helper" settings set clipScale fit >/dev/null
assert_no_gsr_leftovers

export SHADOWPLAY_NOW=1100
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list"
clip=$(saved)
[[ ! -r $segment_index ]] || fail "Segments older than the Replay Window were kept"
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 1 ]] || fail "expired Segments should not be stitched"
[[ $clip == "$replay_dir/Replay-1100.mp4" ]] || fail "Save after discard should be one Clip, got $clip"
[[ -e $clip ]] || fail "discard Clip was not written"
assert_no_gsr_leftovers

"$helper" stop

export SHADOWPLAY_NOW=3000
rm -rf "$replay_dir"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
"$helper" start --monitor=DP-1 --seconds=60 --audio=none >/dev/null
"$helper" settings set audio desktop >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 1 ]] || fail "audio change should Split, got $segment_count"
clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "Save after audio Split did not join"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "anullsrc"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "concat=n=2:v=1:a=1"
if grep -Fxq -- "-an" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"; then
  fail "audio Split join stripped audio"
fi
"$helper" stop

export SHADOWPLAY_NOW=4000
rm -rf "$replay_dir"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
"$helper" start --monitor=DP-1 --seconds=60 --audio=desktop >/dev/null
export SHADOWPLAY_NOW=4060
"$helper" start --monitor=HDMI-A-1 >/dev/null
export SHADOWPLAY_NOW=4110
clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "Save after delayed Split did not join"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "-ss"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "50"
"$helper" stop
# Follow Filter=All: Armed, Live, Sticky, Linger, Split
windows_file="$work/windows.json"
monitors_file="$work/monitors.json"
export SHADOWPLAY_WINDOWS_FILE="$windows_file"
export SHADOWPLAY_MONITORS_FILE="$monitors_file"

write_windows() {
  printf '%s\n' "$1" > "$windows_file"
}

printf '%s\n' '[{"id":0,"name":"HDMI-A-1"},{"id":1,"name":"DP-1","focused":true}]' > "$monitors_file"

"$helper" stop >/dev/null 2>&1 || true
"$helper" settings set mode follow >/dev/null
"$helper" settings set filter all >/dev/null
"$helper" settings set seconds 60 >/dev/null
write_windows '[{"class":"waybar","monitor":"DP-1","address":"0xbar","focused":true}]'
export SHADOWPLAY_NOW=6000
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.mode == "follow" and .filter == "all" and .armed == true and .running == false and .phase == "armed"' >/dev/null \
  || fail "follow autostart should Arm without Live: $status"
[[ ! -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "Armed launched a Replay Buffer on chrome"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox"' >/dev/null \
  || fail "focusing a normal window should go Live: $status"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "DP-1"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "Live did not launch the recorder"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"waybar","monitor":"DP-1","address":"0xbar","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox"' >/dev/null \
  || fail "chrome focus should Sticky: $status"
[[ ! -r $segment_index ]] || fail "Sticky chrome retargeted/Split"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"discord","monitor":"DP-1","address":"0xdc","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox"' >/dev/null \
  || fail "Discord should Sticky the Subject: $status"
[[ ! -r $segment_index ]] || fail "Discord Sticky Split the buffer"

write_windows '[{"class":"waybar","monitor":"DP-1","address":"0xbar","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "linger" and .monitor == "DP-1"' >/dev/null \
  || fail "destroyed Subject should Linger: $status"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff2","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox"' >/dev/null \
  || fail "reopen on same monitor should reclaim without Split: $status"
[[ -r $segment_index ]] || fail "Linger should keep the closed Subject as a Segment"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "Linger reopen stopped capture"

write_windows '[]'
status=$("$helper" tick)
echo "$status" | jq -e '.phase == "linger"' >/dev/null || fail "close again should Linger: $status"
export SHADOWPLAY_NOW=6060
status=$("$helper" tick)
echo "$status" | jq -e '.armed == true and .running == false and .phase == "armed"' >/dev/null \
  || fail "Linger should return to Armed after one Replay Window: $status"
[[ ! -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "Linger expiry left the recorder Live"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":true}]'
export SHADOWPLAY_NOW=7000
"$helper" start >/dev/null
write_windows '[{"class":"kitty","monitor":"HDMI-A-1","address":"0xkit","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "HDMI-A-1" and .subject == "kitty"' >/dev/null \
  || fail "other-monitor allowed window should Split: $status"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "HDMI-A-1"
[[ -r $segment_index ]] || fail "Follow Split did not keep a Segment"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list"
clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "Follow Split Save did not stitch one Clip"
[[ -e $clip ]] || fail "Follow Split Clip missing"
"$helper" stop

# hyprctl clients -j shape: integer monitor ids + focusHistoryID
write_windows '[{"class":"firefox","initialClass":"firefox","monitor":1,"address":"0xff","focusHistoryID":0},{"class":"waybar","monitor":1,"address":"0xbar","focusHistoryID":2}]'
export SHADOWPLAY_NOW=8000
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox"' >/dev/null \
  || fail "hyprctl-shaped clients should resolve focused Subject on connector: $status"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "DP-1"

write_windows '[{"class":"firefox","monitor":1,"address":"0xff","focusHistoryID":1},{"class":"discord","monitor":1,"address":"0xdc","focusHistoryID":0}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox" and .monitor == "DP-1" and .phase == "live"' >/dev/null \
  || fail "hyprctl Discord glance should Sticky: $status"

# Mode change to Follow while already Follow/Live must Split, not discard
"$helper" settings set mode follow >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .phase == "live" and .subject == "firefox"' >/dev/null \
  || fail "setting mode=follow again should keep Live: $status"
[[ ! -r $segment_index ]] || fail "repeat mode=follow discarded/Split unexpectedly"

"$helper" settings set mode monitor >/dev/null
[[ -r $segment_index ]] || fail "mode change away from Follow should Split (keep Segment)"
"$helper" stop

# Follow Window audio: app stream, optional mic, Split when the Subject's app changes.
export SHADOWPLAY_NOW=8300
rm -rf "$replay_dir"
rm -f "$segment_index" "$SHADOWPLAY_FAKE_DIR/gsr.args"
export SHADOWPLAY_APP_AUDIO_JSON='{"class:firefox":"Firefox","class:kitty":"kitty"}'
"$helper" settings set mode follow >/dev/null
"$helper" settings set filter all >/dev/null
"$helper" settings set audio window >/dev/null
write_windows '[{"class":"firefox","pid":4242,"monitor":"DP-1","address":"0xff","focused":true}]'
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.audio == "window" and .running == true and .subject == "firefox"' >/dev/null \
  || fail "window audio status: $status"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "app:Firefox"
if grep -F "default_output" "$SHADOWPLAY_FAKE_DIR/gsr.args" >/dev/null; then
  fail "window audio should not capture desktop output"
fi
"$helper" settings set audio window-mic >/dev/null
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "app:Firefox"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "default_input"
[[ -r $segment_index ]] || fail "switching to window-mic should Split"
write_windows '[{"class":"kitty","pid":4243,"monitor":"DP-1","address":"0xkit","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "kitty" and .monitor == "DP-1" and .phase == "live"' >/dev/null \
  || fail "window audio should follow the new Subject: $status"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "app:kitty"
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 2 ]] || fail "same-monitor app change should Split window audio, got $segment_count"
unset SHADOWPLAY_APP_AUDIO_JSON
"$helper" stop
export SHADOWPLAY_NOW=8350
rm -f "$segment_index" "$SHADOWPLAY_FAKE_DIR/gsr.args"
printf 'Firefox\nBrave\nSpotify\n' > "$SHADOWPLAY_FAKE_DIR/app-audio"
"$helper" settings set audio window >/dev/null
write_windows '[{"class":"brave-browser","pid":10001,"monitor":"DP-1","address":"0xbr","focused":true}]'
"$helper" start >/dev/null
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "app:Brave"
if grep -F "app:brave-browser" "$SHADOWPLAY_FAKE_DIR/gsr.args" >/dev/null; then
  fail "window audio should map brave-browser to GSR name Brave"
fi
"$helper" stop
"$helper" settings set audio desktop >/dev/null

# Follow Capture Extent: default Window, crop, linger gap, Split-on-change
export SHADOWPLAY_NOW=8500
rm -rf "$replay_dir"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "$segment_index"
"$helper" stop >/dev/null 2>&1 || true
mkdir -p "$XDG_CONFIG_HOME/omarchy-instant-replay"
printf 'monitor=\nseconds=60\naudio=desktop\nmode=follow\n' > "$XDG_CONFIG_HOME/omarchy-instant-replay/config"
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.mode == "follow" and .captureExtent == "window"' >/dev/null \
  || fail "Follow config without captureExtent should default Window: $settings"
"$helper" settings set mode follow >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.mode == "follow" and .captureExtent == "window"' >/dev/null \
  || fail "Follow should default Capture Extent to Window: $settings"
write_windows '[{"class":"firefox","pid":4242,"monitor":"DP-1","address":"0xff","focused":true,"at":[3540,80],"size":[800,600]}]'
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.captureExtent == "window" and .running == true and .phase == "live"' >/dev/null \
  || fail "Follow Window extent status: $status"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/ffmpeg.args ]] || fail "Window extent Save should crop through ffmpeg"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "crop=800:600:100:80"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "scale=1920:1080:force_original_aspect_ratio=decrease"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
[[ -e $clip ]] || fail "Window extent Clip missing"
assert_no_gsr_leftovers

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":true,"at":[3440,0],"size":[5120,1440]}]'
"$helper" tick >/dev/null
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
if grep -F "crop=" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" >/dev/null 2>&1; then
  fail "fullscreen Subject should equal Monitor (no crop)"
fi

write_windows '[{"class":"firefox","pid":4242,"monitor":"DP-1","address":"0xff","focused":true,"at":[3540,80],"size":[800,600]}]'
"$helper" tick >/dev/null
"$helper" settings set captureExtent monitor >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.captureExtent == "window" and .running == true' >/dev/null \
  || fail "Follow should ignore monitor extent: $status"
[[ ! -r $segment_index ]] || fail "Follow extent ignore Split the buffer"
"$helper" stop

# Follow same-monitor Subject change: rotate the ring, stitch per-window crops.
export SHADOWPLAY_NOW=8600
rm -rf "$replay_dir"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "$segment_index"
"$helper" settings set mode follow >/dev/null
"$helper" settings set filter all >/dev/null
"$helper" settings set audio desktop >/dev/null
write_windows '[{"class":"firefox","pid":4242,"monitor":"DP-1","address":"0xff","focused":true,"at":[3540,80],"size":[800,600]}]'
"$helper" start >/dev/null
export SHADOWPLAY_NOW=8620
write_windows '[{"class":"kitty","pid":4243,"monitor":"DP-1","address":"0xkit","focused":true,"at":[3440,0],"size":[400,300]}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .subject == "kitty" and .monitor == "DP-1"' >/dev/null \
  || fail "same-monitor Follow should retarget the Subject: $status"
[[ -r $segment_index ]] || fail "same-monitor Subject change should dump a Segment"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "same-monitor Subject change stopped capture"
[[ $(<"$SHADOWPLAY_FAKE_DIR/restart-replay") == true ]] || fail "same-monitor Subject change should clear the Replay Buffer"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "DP-1"
export SHADOWPLAY_NOW=8640
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "same-monitor Follow Save did not stitch"
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 2 ]] || fail "same-monitor Follow Save should join Segment + live"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "crop=800:600:100:80"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "crop=400:300:0:0"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "setpts=PTS-STARTPTS"
[[ -e $clip ]] || fail "same-monitor Follow Clip missing"
assert_no_gsr_leftovers
"$helper" stop

# Odd window sizes even-align for yuv420; many same-monitor swaps still stitch.
export SHADOWPLAY_NOW=8700
rm -rf "$replay_dir"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "$segment_index"
"$helper" settings set mode follow >/dev/null
"$helper" settings set filter all >/dev/null
write_windows '[{"class":"firefox","pid":4242,"monitor":"DP-1","address":"0xff","focused":true,"at":[3541,81],"size":[801,601]}]'
"$helper" start >/dev/null
rm -f "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "crop=800:600:102:82"
"$helper" stop >/dev/null 2>&1 || true
export SHADOWPLAY_NOW=8800
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "$segment_index"
write_windows '[{"class":"firefox","pid":4242,"monitor":"DP-1","address":"0xff","focused":true,"at":[3540,80],"size":[800,600]}]'
"$helper" start >/dev/null
n=1
while (( n <= 5 )); do
  export SHADOWPLAY_NOW=$((8800 + n * 2))
  if (( n % 2 == 1 )); then
    write_windows '[{"class":"kitty","pid":4243,"monitor":"DP-1","address":"0xkit'"$n"'","focused":true,"at":[3440,0],"size":[400,300]}]'
  else
    write_windows '[{"class":"firefox","pid":4242,"monitor":"DP-1","address":"0xff'"$n"'","focused":true,"at":[3540,80],"size":[800,600]}]'
  fi
  "$helper" tick >/dev/null
  n=$((n + 1))
done
[[ $(grep -c . "$segment_index" || true) == 5 ]] || fail "five same-monitor swaps should dump 5 Segments, got $(grep -c . "$segment_index" || true)"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "many Follow swaps stopped capture"
export SHADOWPLAY_NOW=8820
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
clip=$(saved)
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 6 ]] || fail "many Follow swaps should join 5 Segments + live, got $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list")"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/ffmpeg.args" "concat=n=6"
[[ -e $clip ]] || fail "many Follow swaps Clip missing"
assert_no_gsr_leftovers
"$helper" stop

# Region Mode: persist rectangle, reject spanning, re-pick Split.
export SHADOWPLAY_NOW=9000
rm -rf "$replay_dir"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
"$helper" settings set mode region >/dev/null
"$helper" settings set region "400x300+100+50" >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.mode == "region" and .region == "400x300+100+50"' >/dev/null   || fail "region was not persisted: $settings"
"$helper" start >/dev/null
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-w"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "region"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "-region"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "400x300+100+50"
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .mode == "region" and .region == "400x300+100+50" and .monitor == "HDMI-A-1"' >/dev/null   || fail "region start status: $status"
"$helper" stop
"$helper" start >/dev/null
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "400x300+100+50"
"$helper" stop

if "$helper" settings set region "200x200+3400+10" >/dev/null 2>"$work/span-err"; then
  fail "spanning region was accepted"
fi
grep -qi 'span' "$work/span-err" || fail "spanning region error was unclear: $(<"$work/span-err")"

export SHADOWPLAY_REGION_PICKER="$fake_slurp"
export SHADOWPLAY_SLURP_REGION="120,80 200x200"
"$helper" settings set region "400x300+100+50" >/dev/null
"$helper" start --mode=region --region=400x300+100+50 >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ ${segment_count:-0} == 0 ]] || fail "region start should not Split yet, got $segment_count"
"$helper" pick-region >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 1 ]] || fail "re-pick while Live should Split, got $segment_count"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "200x200+120+80"
clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "Save after region re-pick did not join"
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 2 ]] || fail "region re-pick Save should be one Clip from Segment + live"
[[ $clip == "$replay_dir/Replay-9000.mp4" ]] || fail "region re-pick Clip path was $clip"
[[ -e $clip ]] || fail "region re-pick Clip was not written"
assert_no_gsr_leftovers
"$helper" stop

# Follow Filter=Denylist: pre-populated Blacklist, empty is louder than All, Sticky, no Split.
write_windows '[]'
"$helper" stop >/dev/null 2>&1 || true
"$helper" settings set mode follow >/dev/null
"$helper" settings set filter denylist >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.filter == "denylist" and (.blacklist == ["waybar","walker","hyprlock"])' >/dev/null   || fail "denylist should show pre-populated Blacklist: $settings"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":true}]'
export SHADOWPLAY_NOW=10000
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .phase == "live" and .subject == "firefox"' >/dev/null   || fail "denylist start on firefox: $status"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"waybar","monitor":"DP-1","address":"0xbar","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .subject == "firefox"' >/dev/null   || fail "blacklisted chrome should Sticky: $status"
[[ ! -r $segment_index ]] || fail "blacklisted focus Split the buffer"

"$helper" settings set blacklist "walker,hyprlock,waybar" >/dev/null
segment_count=$(grep -c . "$segment_index" || true)
[[ ${segment_count:-0} == 0 ]] || fail "editing Blacklist while Live should not Split, got $segment_count"
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.blacklist == ["walker","hyprlock","waybar"]' >/dev/null   || fail "blacklist reorder was not stored: $settings"

"$helper" settings set blacklist "waybar,walker,hyprlock,kitty" >/dev/null
write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"kitty","monitor":"DP-1","address":"0xkit","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox" and .phase == "live"' >/dev/null   || fail "added blacklist class should Sticky: $status"
[[ ! -r $segment_index ]] || fail "sticky-on-blacklist Split"

"$helper" settings set blacklist "" >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.filter == "denylist" and (.blacklist | length) == 0' >/dev/null   || fail "empty Blacklist was not stored: $settings"
grep -qx 'blacklist=' "$XDG_CONFIG_HOME/omarchy-instant-replay/config" \
  || fail "empty Blacklist should persist as an empty key, not re-seed"
write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"waybar","monitor":"DP-1","address":"0xbar","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .subject == "waybar"' >/dev/null   || fail "empty Denylist should follow chrome that All still skips: $status"
[[ -r $segment_index ]] || fail "empty Denylist chrome follow should rotate the Replay Buffer"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "empty Denylist chrome follow stopped capture"

export SHADOWPLAY_WINDOW_PICKER="$fake_window"
export SHADOWPLAY_PICKED_WINDOW="0xkit"
write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":true},{"class":"kitty","monitor":"DP-1","address":"0xkit","focused":false}]'
"$helper" settings set blacklist "waybar,walker,hyprlock" >/dev/null
settings=$("$helper" pick-blacklist-window)
echo "$settings" | jq -e '.mode == "follow" and .filter == "denylist" and (.blacklist | index("kitty") != null)' >/dev/null \
  || fail "pick-blacklist-window should add the clicked window class: $settings"
echo "$settings" | jq -e '.mode != "pin"' >/dev/null || fail "blacklist pick switched to Pin"
unset SHADOWPLAY_WINDOW_PICKER
unset SHADOWPLAY_PICKED_WINDOW

"$helper" settings set filter all >/dev/null
write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"waybar","monitor":"DP-1","address":"0xbar","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox" or .subject == "waybar"' >/dev/null   || fail "filter all tick status: $status"
# restore firefox as subject then chrome sticky under All
write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox"' >/dev/null || fail "return to firefox: $status"
write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"waybar","monitor":"DP-1","address":"0xbar","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox" and .phase == "live"' >/dev/null   || fail "Filter=All should still skip built-in chrome: $status"
"$helper" stop

# Follow Filter=Allowlist: class match, sticky, priority, regex, live list edit, split.
write_windows '[]'
"$helper" stop >/dev/null 2>&1 || true
"$helper" settings set mode follow >/dev/null
"$helper" settings set filter allowlist >/dev/null
"$helper" settings set matchList "firefox,kitty" >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.filter == "allowlist" and .matchList[0] == "firefox" and .matchList[1] == "kitty"' >/dev/null \
  || fail "allowlist matchList not stored: $settings"

write_windows '[{"class":"discord","title":"Friends","monitor":"DP-1","address":"0xdc","focused":true}]'
export SHADOWPLAY_NOW=10000
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.armed == true and .running == false and .phase == "armed"' >/dev/null \
  || fail "allowlist should Arm on a non-match: $status"

write_windows '[{"class":"firefox","title":"Mozilla Firefox","initialClass":"firefox","monitor":"DP-1","address":"0xff","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .subject == "firefox" and .monitor == "DP-1"' >/dev/null \
  || fail "allowlist focused match should go Live: $status"

write_windows '[{"class":"firefox","title":"Mozilla Firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"discord","title":"Friends","monitor":"DP-1","address":"0xdc","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox" and .phase == "live" and .monitor == "DP-1"' >/dev/null \
  || fail "non-match glance should Sticky: $status"
[[ ! -r $segment_index ]] || fail "allowlist Sticky Split"

write_windows '[{"class":"kitty","title":"term","monitor":"HDMI-A-1","address":"0xkit","focused":true},{"class":"firefox","title":"Mozilla Firefox","monitor":"DP-1","address":"0xff","focused":false}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "kitty" and .monitor == "HDMI-A-1" and .phase == "live"' >/dev/null \
  || fail "focused match on another monitor should Split: $status"
[[ -r $segment_index ]] || fail "allowlist other-monitor match did not Split"

write_windows '[{"class":"firefox","title":"Mozilla Firefox","monitor":"HDMI-A-1","address":"0xff","focused":false},{"class":"kitty","title":"term","monitor":"HDMI-A-1","address":"0xkit","focused":false},{"class":"waybar","monitor":"HDMI-A-1","address":"0xbar","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "kitty" and .monitor == "HDMI-A-1"' >/dev/null \
  || fail "chrome glance should keep Sticky kitty: $status"

# Neither match focused: list order is priority (firefox first) once the Subject is gone.
write_windows '[{"class":"firefox","title":"Mozilla Firefox","monitor":"HDMI-A-1","address":"0xff","focused":false},{"class":"kitty","title":"term","monitor":"HDMI-A-1","address":"0xkit","focused":false}]'
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "kitty"' >/dev/null \
  || fail "living Subject should stay Sticky when no match is focused: $status"

write_windows '[{"class":"firefox","title":"Mozilla Firefox","monitor":"HDMI-A-1","address":"0xff","focused":false}]'
# kitty gone; neither match focused; priority should pick firefox (first rule)
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox" and .monitor == "HDMI-A-1"' >/dev/null \
  || fail "priority should pick first Match List rule when none focused: $status"
[[ $(grep -c . "$segment_index" || true) == 2 ]] || fail "same-monitor priority pick should rotate the Replay Buffer, got $(grep -c . "$segment_index" || true)"
[[ -e $SHADOWPLAY_FAKE_DIR/running ]] || fail "same-monitor priority pick stopped capture"

"$helper" settings set matchList "^fire.*" >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.matchList[0] == "^fire.*"' >/dev/null || fail "regex matchList not stored: $settings"
status=$("$helper" tick)
echo "$status" | jq -e '.subject == "firefox" and .phase == "live"' >/dev/null \
  || fail "regex should keep firefox: $status"
segment_count=$(grep -c . "$segment_index" || true)
[[ $segment_count == 2 ]] || fail "editing Match List while Live Split, got $segment_count"

windows=$("$helper" windows --json)
echo "$windows" | jq -e '.[0].class == "firefox" and .[0].title == "Mozilla Firefox"' >/dev/null \
  || fail "windows json should expose class and title: $windows"
echo "$windows" | jq -e '.[0].class != .[0].title' >/dev/null \
  || fail "windows json should not use title as class: $windows"

"$helper" stop >/dev/null
"$helper" settings set matchList "Firefox" >/dev/null
write_windows '[{"class":"discord","title":"Firefox","monitor":"DP-1","address":"0xd","focused":true}]'
export SHADOWPLAY_NOW=10500
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.armed == true and .running == false and .phase == "armed"' >/dev/null \
  || fail "title must not match Match List rules: $status"

write_windows '[{"class":"Navigator","initialClass":"firefox","title":"Mozilla Firefox","monitor":"DP-1","address":"0xff","focused":true}]'
"$helper" settings set matchList "firefox" >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .phase == "live" and .subject == "Navigator" and .monitor == "DP-1"' >/dev/null \
  || fail "initialClass should match Match List: $status"

"$helper" stop >/dev/null
"$helper" settings set matchList "steam,firefox" >/dev/null
write_windows '[{"class":"firefox","title":"Mozilla Firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"steam","title":"Steam","monitor":"DP-1","address":"0xst","focused":false},{"class":"waybar","title":"bar","monitor":"DP-1","address":"0xbar","focused":true}]'
export SHADOWPLAY_NOW=11000
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.running == true and .subject == "steam" and .monitor == "DP-1"' >/dev/null \
  || fail "priority should pick earlier Match List rule when none focused: $status"

"$helper" stop

# Pin Mode: window picker, glance does not follow, move-output Split.
export SHADOWPLAY_NOW=10000
rm -rf "$replay_dir"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list" "$SHADOWPLAY_FAKE_DIR/ffmpeg.args"
export SHADOWPLAY_WINDOW_PICKER="$fake_window"
export SHADOWPLAY_PICKED_WINDOW="0xff"
"$helper" stop >/dev/null 2>&1 || true
"$helper" settings set mode pin >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.mode == "pin" and .captureExtent == "window"' >/dev/null \
  || fail "Pin Mode should force Window extent: $settings"
"$helper" pick-window >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.mode == "pin" and .pinAddress == "0xff"' >/dev/null \
  || fail "pick-window did not persist pin target: $settings"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":true}]'
export SHADOWPLAY_NOW=10000
"$helper" start >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.mode == "pin" and .running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox" and .pinAddress == "0xff" and .captureExtent == "window"' >/dev/null \
  || fail "pin start should follow only the pinned window: $status"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "DP-1"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"discord","monitor":"DP-1","address":"0xdc","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox"' >/dev/null \
  || fail "glance should not retarget Pin: $status"
[[ ! -r $segment_index ]] || fail "Pin glance Split the buffer"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"kitty","monitor":"HDMI-A-1","address":"0xkit","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "DP-1" and .subject == "firefox"' >/dev/null \
  || fail "glance on another output should not retarget Pin: $status"
[[ ! -r $segment_index ]] || fail "Pin other-output glance Split the buffer"

"$helper" settings set captureExtent monitor >/dev/null
settings=$("$helper" settings show --json)
echo "$settings" | jq -e '.mode == "pin" and .captureExtent == "window"' >/dev/null \
  || fail "Pin Mode must stay Window extent: $settings"

write_windows '[{"class":"firefox","monitor":"DP-1","address":"0xff","focused":false},{"class":"kitty","monitor":"DP-1","address":"0xkit","focused":true}]'
"$helper" settings set pinAddress 0xkit >/dev/null
status=$("$helper" status --json)
echo "$status" | jq -e '.subject == "kitty" and .monitor == "DP-1" and .pinAddress == "0xkit"' >/dev/null \
  || fail "Pin retarget same output should not Split: $status"
segment_count=$(grep -c . "$segment_index" 2>/dev/null || true)
[[ ${segment_count:-0} == 0 ]] || fail "Pin target change on same output Split, got $segment_count"

"$helper" settings set pinAddress 0xff >/dev/null
write_windows '[{"class":"firefox","monitor":"HDMI-A-1","address":"0xff","focused":false},{"class":"discord","monitor":"DP-1","address":"0xdc","focused":true}]'
status=$("$helper" tick)
echo "$status" | jq -e '.running == true and .phase == "live" and .monitor == "HDMI-A-1" and .subject == "firefox"' >/dev/null \
  || fail "pinned window moving output should Split: $status"
assert_file_contains "$SHADOWPLAY_FAKE_DIR/gsr.args" "HDMI-A-1"
[[ -r $segment_index ]] || fail "Pin move-output Split did not keep a Segment"
rm -f "$SHADOWPLAY_FAKE_DIR/concat.list"
clip=$(saved)
[[ -e $SHADOWPLAY_FAKE_DIR/concat.list ]] || fail "Pin Split Save did not stitch one Clip"
[[ $(wc -l < "$SHADOWPLAY_FAKE_DIR/concat.list") == 2 ]] || fail "Pin Split Save should join Segment + live"
[[ -e $clip ]] || fail "Pin Split Clip missing"
assert_no_gsr_leftovers
"$helper" stop

echo OK
