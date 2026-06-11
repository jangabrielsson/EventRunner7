#!/bin/bash
# test/run-tests.sh — Regression test runner for EventRunner7
#
# Runs each test file in test/expr/ and test/rules/ as a separate
# plua process.  Isolated processes ensure rules never interfere
# between tests.  Each test writes a log to test/results/<name>.log.
#
# Usage:
#   ./test/run-tests.sh              # run all tests
#   ./test/run-tests.sh expr         # expression tests only
#   ./test/run-tests.sh rules        # rule tests only
#   ./test/run-tests.sh -v           # verbose (show plua output)
#   ./test/run-tests.sh --clean      # remove old logs first

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/results"

cd "$PROJECT_DIR"

PASS=0
FAIL=0
VERBOSE=false
TIMEOUT=15  # seconds per test (plua --run-for 0 relies on os.exit)

# Parse flags
TESTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) VERBOSE=true; shift ;;
    --clean) rm -rf "$RESULTS_DIR"; shift ;;
    expr) TESTS+=("$SCRIPT_DIR/expr/"*.lua); shift ;;
    rules) TESTS+=("$SCRIPT_DIR/rules/"*.lua); shift ;;
    *) TESTS+=("$1"); shift ;;
  esac
done

# Default: all tests
if [[ ${#TESTS[@]} -eq 0 ]]; then
  shopt -s nullglob
  TESTS=("$SCRIPT_DIR/expr/"*.lua "$SCRIPT_DIR/rules/"*.lua)
  shopt -u nullglob
fi

if [[ ${#TESTS[@]} -eq 0 ]]; then
  echo "No test files found."
  exit 1
fi

mkdir -p "$RESULTS_DIR"

echo "=== EventRunner7 Regression Suite ==="
echo ""

for test_file in "${TESTS[@]}"; do
  [[ -f "$test_file" ]] || continue
  name=$(basename "$test_file" .lua)
  dir=$(basename "$(dirname "$test_file")")
  label="$dir/$name"

  if $VERBOSE; then
    echo "── $label ──────────────────────────────"
    if plua --fibaro --run-for "$TIMEOUT" "$test_file" 2>&1; then
      PASS=$((PASS + 1))
      echo "  PASS"
    else
      FAIL=$((FAIL + 1))
      echo "  FAIL (exit code $?)"
    fi
    echo ""
  else
    printf "  %-45s " "$label"
    output=$(plua --fibaro --run-for "$TIMEOUT" "$test_file" 2>&1) && rc=$? || rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "PASS"
      PASS=$((PASS + 1))
    else
      echo "FAIL"
      FAIL=$((FAIL + 1))
      # Show FAIL lines from both stdout and the log file
      echo "$output" | grep -E "FAIL:" || true
      # Check for a log file
      logname=$(echo "$name" | tr '[:lower:]' '[:upper:]')
      logfile=$(ls "$RESULTS_DIR"/"${logname}"*.log 2>/dev/null | head -1)
      if [[ -n "$logfile" ]]; then
        echo "        log: $logfile"
      fi
    fi
  fi
done

echo ""
echo "─────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
echo "Logs:   $RESULTS_DIR/"
echo "─────────────────────────────────────────"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
