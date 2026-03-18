#!/bin/bash
# bashnative/z_build/tests/test-container.sh
# Builds and runs bashnative in a Docker container.
# You get an interactive bash prompt where the ONLY tools are bashnative.
#
# Usage: ./test-container.sh          # build and run interactively
#        ./test-container.sh build    # build only
#        ./test-container.sh run      # run only (must build first)
#        ./test-container.sh test     # run automated smoke tests

set -e

BASHNATIVE="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE="bashnative:latest"

build () {
   echo "Building bashnative container..."
   echo "(this compiles bash from source, may take a minute)"
   echo
   docker build -t "$IMAGE" "$BASHNATIVE"
   echo
   echo "Built: $IMAGE"
}

run_interactive () {
   echo "Entering bashnative container. Only bashnative tools are available."
   echo "Type 'exit' to leave."
   echo
   docker run --rm -it "$IMAGE"
}

run_tests () {
   echo "Running smoke tests in container..."
   echo

   docker run --rm "$IMAGE" -c '
      PASS=0
      FAIL=0

      check () {
         local DESC="$1"
         shift
         if eval "$@" >/dev/null 2>&1; then
            echo "  PASS: $DESC"
            (( PASS++ ))
         else
            echo "  FAIL: $DESC"
            (( FAIL++ ))
         fi
      }

      echo "=== bashnative smoke tests ==="
      echo

      # trivials
      check "true"              "true"
      check "false returns 1"   "! false"
      check "echo"              "echo hello | grep -q hello"
      check "pwd"               "test -n \"\$(pwd)\""
      check "hostname"          "test -n \"\$(hostname)\""
      check "whoami"            "test -n \"\$(whoami)\""
      check "uname"             "test -n \"\$(uname)\""
      check "which bash"        "which bash | grep -q /bin/bash"

      # mk builtin (the big one!)
      check "mk dir"            "mk dir /tmp/bntest"
      check "mk dir -p"         "mk dir -p /tmp/bntest/a/b/c"
      check "mk fifo"           "mk fifo /tmp/bntest/pipe"
      check "mkdir script"      "mkdir /tmp/bntest2"
      check "mkfifo script"     "mkfifo /tmp/bntest2/pipe2"

      # text filters
      check "head"              "printf \"a\nb\nc\n\" | head -n 1 | grep -q a"
      check "tail"              "printf \"a\nb\nc\n\" | tail -n 1 | grep -q c"
      check "wc"                "echo hello | wc -w | grep -q 1"
      check "rev"               "echo abc | rev | grep -q cba"
      check "sort"              "printf \"b\na\n\" | sort | head -n 1 | grep -q a"
      check "uniq"              "printf \"a\na\nb\n\" | uniq | wc -l | grep -q 2"
      check "cut"               "echo one:two | cut -d: -f2 | grep -q two"
      check "nl"                "echo hi | nl | grep -q 1"
      check "fold"              "echo abcdefgh | fold -w 4 | head -n 1 | grep -q abcd"
      check "tee"               "echo hi | tee /tmp/bntest/tee.out | grep -q hi"
      check "tr"                "echo hello | tr el ip | grep -q hippo"

      # file operations
      check "touch"             "touch /tmp/bntest/touched && test -f /tmp/bntest/touched"
      check "cp"                "echo data > /tmp/bntest/src && cp /tmp/bntest/src /tmp/bntest/dst && grep -q data /tmp/bntest/dst"
      check "cat"               "echo test > /tmp/bntest/catfile && cat /tmp/bntest/catfile | grep -q test"
      check "basename"          "test \"\$(basename /a/b/c.sh)\" = c.sh"
      check "dirname"           "test \"\$(dirname /a/b/c)\" = /a/b"
      check "seq"               "test \"\$(seq 1 3 | wc -l)\" -ge 3"
      check "mktemp"            "TMPF=\$(mktemp) && test -f \"\$TMPF\""

      # advanced
      check "grep"              "echo hello world | grep -q world"
      check "grep -v"           "printf \"yes\nno\n\" | grep -v no | grep -q yes"
      check "base64 encode"     "echo -n hi | base64 | grep -q aGk"
      check "printf"            "test \"\$(printf \"%d\" 42)\" = 42"
      check "kill -l"           "kill -l | grep -q TERM"
      check "sleep"             "sleep 1"
      check "date"              "test -n \"\$(date)\""
      check "xargs"             "echo hello | xargs echo | grep -q hello"

      echo
      echo "=== Results: $PASS passed, $FAIL failed ==="
      (( FAIL == 0 )) && exit 0 || exit 1
   '
}

main () {
   case "${1:-all}" in
      build)
         build
         ;;
      run)
         run_interactive
         ;;
      test)
         if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
            build
         fi
         run_tests
         ;;
      all|"")
         build
         run_interactive
         ;;
      *)
         echo "Usage: $0 [build|run|test|all]"
         exit 1
         ;;
   esac
}

main "$@"
