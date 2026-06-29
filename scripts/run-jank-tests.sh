#!/usr/bin/env bash
# Run the Jank Clojure Test Suite against Swish.
# Usage: bash scripts/run-jank-tests.sh
# Set CTS_DIR to use an existing clone: CTS_DIR=/path/to/clojure-test-suite bash scripts/run-jank-tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUPPORT_DIR="$PROJECT_DIR/support"
CTS_DIR="${CTS_DIR:-/tmp/clojure-test-suite}"

if [ ! -f "$CTS_DIR/test/clojure/core_test/abs.cljc" ]; then
  rm -rf "$CTS_DIR"
  echo "Cloning Jank Clojure Test Suite into $CTS_DIR ..."
  git clone https://github.com/jank-lang/clojure-test-suite "$CTS_DIR"
fi

RUNNER=$(mktemp /tmp/swish-runner-XXXXXX.clj)
trap "rm -f $RUNNER" EXIT

{
  echo "(ns swish.test-runner"
  echo "  (:require [clojure.test :as t]"
  find "$CTS_DIR/test" -name "*.cljc" | sort | while IFS= read -r f; do
    rel="${f#$CTS_DIR/test/}"
    ns=$(echo "${rel%.cljc}" | tr '/' '.' | tr '_' '-')
    echo "            [$ns]"
  done
  echo "  ))"
  find "$CTS_DIR/test" -name "*.cljc" | sort | while IFS= read -r f; do
    rel="${f#$CTS_DIR/test/}"
    ns=$(echo "${rel%.cljc}" | tr '/' '.' | tr '_' '-')
    echo "(t/run-tests '$ns)"
  done
} >"$RUNNER"

cd "$PROJECT_DIR"
swift run swish --sourcepath "$SUPPORT_DIR:$CTS_DIR/test" "$RUNNER"
