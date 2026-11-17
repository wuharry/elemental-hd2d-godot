#!/bin/zsh
# Regression for the old false-success bug; replaces only the child godot executable.
set -eu
cd "$(dirname "$0")/.."
fixture=$(mktemp -d)
tag="capture_regression_$$"
output="test_output/shot_day_${tag}.png"
trap 'rm -f "$output"; rm -rf "$fixture"' EXIT
mkdir -p test_output
check_exit() {
  local expected=$1
  shift
  local actual=0
  PATH="$fixture:$PATH" CAPTURE_TIMEOUT_SECONDS=1 tools/capture.sh "$@" > "$fixture/result.log" 2>&1 || actual=$?
  if (( actual != expected )); then
    cat "$fixture/result.log"
    print -u2 "FAIL: expected exit $expected, got $actual"
    exit 1
  fi
}
cat > "$fixture/godot" <<'STUB'
#!/bin/zsh
exit 0
STUB
chmod +x "$fixture/godot"
check_exit 1 --shots=day --tag="$tag"
print stale > "$output"
check_exit 1 --shots=day --tag="$tag"
cat > "$fixture/godot" <<'STUB'
#!/bin/zsh
exit 7
STUB
check_exit 7 --shots=day --tag="$tag"
cat > "$fixture/godot" <<'STUB'
#!/bin/zsh
exec sleep 10
STUB
check_exit 124 --shots=day --tag="$tag"
check_exit 2 --shots=invalid --tag="$tag"
check_exit 2 --shots=day --tag=../../outside
print '6 passed, 0 failed'
