#!/bin/zsh
# 開視窗驗收；失敗、逾時、舊圖或缺圖都回傳非零。
set -eu
cd "$(dirname "$0")/.."
mkdir -p test_output
if ! mkdir test_output/.capture-lock 2>/dev/null; then
  print -u2 "Another capture is running (test_output/.capture-lock)."
  exit 1
fi
capture_pid=""
marker=""
cleanup() {
  if [[ -n "$capture_pid" ]] && kill -0 "$capture_pid" 2>/dev/null; then
    kill "$capture_pid" 2>/dev/null || true
    wait "$capture_pid" 2>/dev/null || true
  fi
  [[ -z "$marker" ]] || rm -f "$marker"
  rmdir test_output/.capture-lock
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

shots=(morning day dusk night)
tag=""
for arg in "$@"; do
  case "$arg" in
    --shots=*) shots=("${(@s:,:)${arg#--shots=}}") ;;
    --tag=*) tag="${arg#--tag=}" ;;
  esac
done
# Validate filename components before using them, including on a failed game launch.
if [[ -n "$tag" && "$tag" == *[^A-Za-z0-9_-]* ]]; then
  print -u2 "Invalid capture tag."
  exit 2
fi
for shot in "${shots[@]}"; do
  case "$shot" in
    morning|day|dusk|night) ;;
    *) print -u2 "Invalid capture time: $shot"; exit 2 ;;
  esac
done
timeout_seconds="${CAPTURE_TIMEOUT_SECONDS:-180}"
if [[ "$timeout_seconds" != <1-> ]]; then
  print -u2 "CAPTURE_TIMEOUT_SECONDS must be a positive integer."
  exit 2
fi
marker=$(mktemp test_output/.capture-start.XXXXXX)
godot --path . -- --capture "$@" > test_output/run.log 2>&1 &
capture_pid=$!
elapsed=0
while kill -0 "$capture_pid" 2>/dev/null; do
  if (( elapsed >= timeout_seconds )); then
    print -u2 "Capture timed out after ${timeout_seconds}s."
    cat test_output/run.log
    exit 124
  fi
  sleep 1
  (( elapsed += 1 ))
done
result=0
wait "$capture_pid" || result=$?
capture_pid=""
cat test_output/run.log
if (( result != 0 )); then
  exit "$result"
fi
if grep -Eq '^(SCRIPT ERROR:|ERROR:)' test_output/run.log; then
  print -u2 "Godot reported an error; capture failed."
  exit 1
fi
suffix=""
[[ -z "$tag" ]] || suffix="_$tag"
expected=()
for shot in "${shots[@]}"; do
  expected+=("test_output/shot_${shot}${suffix}.png")
done
[[ -n "$tag" ]] || expected+=(test_output/shot_night_cast.png)
for output in "${expected[@]}"; do
  if [[ ! -s "$output" || ! "$output" -nt "$marker" ]]; then
    print -u2 "Missing fresh capture: $output"
    exit 1
  fi
done
print "PASS: ${#expected[@]} fresh captures."
