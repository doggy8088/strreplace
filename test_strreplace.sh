#!/usr/bin/env bash
# =============================================================================
# Test suite for strreplace.sh
# =============================================================================
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/strreplace.sh"
PASS=0
FAIL=0
SKIP=0

# Colors
C_RESET="\033[0m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[0;36m"

# Temp workspace
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

pass() { PASS=$((PASS+1)); printf "${C_GREEN}✓${C_RESET} %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "${C_RED}✗${C_RESET} %s\n" "$1"; }
skip() { SKIP=$((SKIP+1)); printf "${C_YELLOW}~${C_RESET} %s\n" "$1"; }

section() {
  echo ""
  printf "${C_BOLD}${C_CYAN}── %s ──────────────────────────────${C_RESET}\n" "$1"
}

assert_file_contains() {
  local file="$1" expected="$2" label="$3"
  if grep -qF "$expected" "$file"; then
    pass "$label"
  else
    fail "$label"
    echo "  Expected to find: $expected"
    echo "  File contents:    $(cat "$file")"
  fi
}

assert_file_not_contains() {
  local file="$1" unexpected="$2" label="$3"
  if ! grep -qF "$unexpected" "$file"; then
    pass "$label"
  else
    fail "$label"
    echo "  Expected NOT to find: $unexpected"
    echo "  File contents: $(cat "$file")"
  fi
}

assert_exit_code() {
  local code="$1" expected="$2" label="$3"
  if [[ "$code" -eq "$expected" ]]; then
    pass "$label"
  else
    fail "$label"
    echo "  Expected exit code $expected, got $code"
  fi
}

# ---------------------------------------------------------------------------
section "Basic string replacement"
# ---------------------------------------------------------------------------

d="$WORKDIR/basic"
mkdir -p "$d"
echo "hello world" > "$d/a.txt"
bash "$SCRIPT" "world" "earth" "$d/a.txt"
assert_file_contains    "$d/a.txt" "hello earth" "simple word replacement"
assert_file_not_contains "$d/a.txt" "world"       "original word removed"

# ---------------------------------------------------------------------------
section "Regex replacement (ERE)"
# ---------------------------------------------------------------------------

d="$WORKDIR/regex"
mkdir -p "$d"
echo "release: v1.2.3" > "$d/ver.txt"
bash "$SCRIPT" 'v[0-9]+\.[0-9]+\.[0-9]+' 'v9.9.9' "$d/ver.txt"
assert_file_contains "$d/ver.txt" "v9.9.9" "version regex replacement"

# Capture groups (using \3-\2-\1 so no slashes in replacement)
echo "2024-01-15" > "$d/date.txt"
bash "$SCRIPT" '([0-9]{4})-([0-9]{2})-([0-9]{2})' '\3-\2-\1' "$d/date.txt"
assert_file_contains "$d/date.txt" "15-01-2024" "capture group reorder"

# ---------------------------------------------------------------------------
section "Multiple files via glob"
# ---------------------------------------------------------------------------

d="$WORKDIR/glob"
mkdir -p "$d"
for f in a b c; do
  echo "old_value" > "$d/${f}.txt"
done
bash "$SCRIPT" "old_value" "new_value" "$d"/*.txt
for f in a b c; do
  assert_file_contains "$d/${f}.txt" "new_value" "glob replacement in ${f}.txt"
done

# ---------------------------------------------------------------------------
section "Recursive flag (-r)"
# ---------------------------------------------------------------------------

d="$WORKDIR/recursive"
mkdir -p "$d/sub/subsub"
echo "find me" > "$d/root.txt"
echo "find me" > "$d/sub/child.txt"
echo "find me" > "$d/sub/subsub/deep.txt"

bash "$SCRIPT" -r "find me" "found" "$d"
assert_file_contains "$d/root.txt"           "found" "recursive: root"
assert_file_contains "$d/sub/child.txt"      "found" "recursive: sub"
assert_file_contains "$d/sub/subsub/deep.txt" "found" "recursive: deep"

# ---------------------------------------------------------------------------
section "Dry-run (-n) does not modify files"
# ---------------------------------------------------------------------------

d="$WORKDIR/dryrun"
mkdir -p "$d"
echo "original" > "$d/f.txt"
bash "$SCRIPT" -n "original" "changed" "$d/f.txt" >/dev/null
assert_file_contains    "$d/f.txt" "original" "dry-run: file not modified"
assert_file_not_contains "$d/f.txt" "changed"  "dry-run: new content absent"

# ---------------------------------------------------------------------------
section "Case-insensitive matching (-i)"
# ---------------------------------------------------------------------------

d="$WORKDIR/icase"
mkdir -p "$d"
echo "Hello WORLD hello" > "$d/f.txt"
bash "$SCRIPT" -i "hello" "hi" "$d/f.txt"
assert_file_contains    "$d/f.txt" "hi WORLD hi" "case-insensitive: all replaced"
assert_file_not_contains "$d/f.txt" "Hello"        "case-insensitive: original gone"

# ---------------------------------------------------------------------------
section "Literal flag (-l) escapes regex metacharacters"
# ---------------------------------------------------------------------------

d="$WORKDIR/literal"
mkdir -p "$d"
echo "foo.bar() = 42" > "$d/f.txt"
bash "$SCRIPT" -l "foo.bar()" "baz.qux()" "$d/f.txt"
assert_file_contains "$d/f.txt" "baz.qux() = 42" "literal: metacharacters escaped"

# ---------------------------------------------------------------------------
section "Backup flag (-b)"
# ---------------------------------------------------------------------------

d="$WORKDIR/backup"
mkdir -p "$d"
echo "original" > "$d/f.txt"
bash "$SCRIPT" -b "original" "changed" "$d/f.txt"
assert_file_contains "$d/f.txt"     "changed"  "backup: file modified"
assert_file_contains "$d/f.txt.bak" "original" "backup: .bak file created"

# Custom backup suffix
echo "data" > "$d/g.txt"
bash "$SCRIPT" -b --backup-suffix ".orig" "data" "info" "$d/g.txt"
[[ -f "$d/g.txt.orig" ]] && pass "backup: custom suffix .orig" || fail "backup: custom suffix .orig"

# ---------------------------------------------------------------------------
section "--include filter"
# ---------------------------------------------------------------------------

d="$WORKDIR/include"
mkdir -p "$d"
echo "old" > "$d/a.txt"
echo "old" > "$d/b.md"
echo "old" > "$d/c.sh"
bash "$SCRIPT" -r --include "*.txt" "old" "new" "$d"
assert_file_contains    "$d/a.txt" "new" "include: .txt replaced"
assert_file_contains    "$d/b.md"  "old" "include: .md skipped"
assert_file_contains    "$d/c.sh"  "old" "include: .sh skipped"

# ---------------------------------------------------------------------------
section "--exclude filter"
# ---------------------------------------------------------------------------

d="$WORKDIR/exclude"
mkdir -p "$d"
echo "old" > "$d/a.txt"
echo "old" > "$d/b.min.js"
bash "$SCRIPT" -r --exclude "*.min.js" "old" "new" "$d"
assert_file_contains    "$d/a.txt"    "new" "exclude: a.txt replaced"
assert_file_contains    "$d/b.min.js" "old" "exclude: .min.js skipped"

# ---------------------------------------------------------------------------
section "--exclude-dir filter"
# ---------------------------------------------------------------------------

d="$WORKDIR/excldir"
mkdir -p "$d/.git" "$d/src"
echo "old" > "$d/.git/config"
echo "old" > "$d/src/main.txt"
bash "$SCRIPT" -r --exclude-dir ".git" "old" "new" "$d"
assert_file_contains    "$d/src/main.txt" "new" "exclude-dir: src processed"
assert_file_contains    "$d/.git/config"  "old" "exclude-dir: .git skipped"

# ---------------------------------------------------------------------------
section "--max-depth"
# ---------------------------------------------------------------------------

d="$WORKDIR/maxdepth"
mkdir -p "$d/l1/l2/l3"
echo "old" > "$d/l1/f.txt"
echo "old" > "$d/l1/l2/f.txt"
echo "old" > "$d/l1/l2/l3/f.txt"
bash "$SCRIPT" -r --max-depth 1 "old" "new" "$d/l1"
assert_file_contains    "$d/l1/f.txt"       "new" "max-depth: depth-0 file modified"
assert_file_contains    "$d/l1/l2/f.txt"    "old" "max-depth: depth-1 file skipped"
assert_file_contains    "$d/l1/l2/l3/f.txt" "old" "max-depth: depth-2 file skipped"

# ---------------------------------------------------------------------------
section "Multiple replacements on same line"
# ---------------------------------------------------------------------------

d="$WORKDIR/multi"
mkdir -p "$d"
echo "aaa bbb aaa" > "$d/f.txt"
bash "$SCRIPT" "aaa" "zzz" "$d/f.txt"
assert_file_contains "$d/f.txt" "zzz bbb zzz" "global replace on same line"

# ---------------------------------------------------------------------------
section "No match: file unchanged"
# ---------------------------------------------------------------------------

d="$WORKDIR/nomatch"
mkdir -p "$d"
echo "content" > "$d/f.txt"
bash "$SCRIPT" "nonexistent" "replacement" "$d/f.txt"
assert_file_contains    "$d/f.txt" "content"     "no match: file unchanged"
assert_file_not_contains "$d/f.txt" "replacement" "no match: replacement absent"

# ---------------------------------------------------------------------------
section "--version flag"
# ---------------------------------------------------------------------------

out=$(bash "$SCRIPT" --version 2>&1)
if echo "$out" | grep -q "v[0-9]\+\.[0-9]\+\.[0-9]\+"; then
  pass "--version outputs version string"
else
  fail "--version outputs version string"
fi

# ---------------------------------------------------------------------------
section "Error handling: no args"
# ---------------------------------------------------------------------------

set +e
bash "$SCRIPT" 2>/dev/null
code=$?
set -e
assert_exit_code "$code" 1 "exits 1 with no arguments"

# ---------------------------------------------------------------------------
section "Error handling: nonexistent file"
# ---------------------------------------------------------------------------

set +e
out=$(bash "$SCRIPT" "foo" "bar" "/nonexistent/path/file.txt" 2>&1)
code=$?
set -e
# Should warn but exit 0 (best-effort on multi-file)
if echo "$out" | grep -qi "no match\|no such\|not found\|warn"; then
  pass "warns on nonexistent file"
else
  fail "warns on nonexistent file"
fi

# ---------------------------------------------------------------------------
section "URLs with slashes in pattern/replacement"
# ---------------------------------------------------------------------------

d="$WORKDIR/urls"
mkdir -p "$d"
echo "endpoint: http://old-api.example.com/v1/users" > "$d/config.txt"
bash "$SCRIPT" "http://old-api.example.com/v1" "https://new-api.example.com/v2" "$d/config.txt"
assert_file_contains    "$d/config.txt" "https://new-api.example.com/v2/users" "URL replacement with slashes"
assert_file_not_contains "$d/config.txt" "http://old-api.example.com" "old URL removed"

# ---------------------------------------------------------------------------
section "--count flag (-C)"
# ---------------------------------------------------------------------------

d="$WORKDIR/count"
mkdir -p "$d"
printf "foo\nfoo\nfoo\n" > "$d/f.txt"
out=$(bash "$SCRIPT" -C "foo" "bar" "$d/f.txt" 2>&1)
if echo "$out" | grep -q "3"; then
  pass "--count: reports 3 replacements"
else
  fail "--count: reports 3 replacements"
  echo "  Output: $out"
fi

# ---------------------------------------------------------------------------
section "--quiet flag suppresses output"
# ---------------------------------------------------------------------------

d="$WORKDIR/quiet"
mkdir -p "$d"
echo "old" > "$d/f.txt"
out=$(bash "$SCRIPT" -q "old" "new" "$d/f.txt" 2>&1)
assert_file_contains "$d/f.txt" "new" "quiet: file still modified"
if [[ -z "$out" ]]; then
  pass "quiet: no output printed"
else
  fail "quiet: no output printed"
  echo "  Got: $out"
fi

# ---------------------------------------------------------------------------
section "Pipe character (|) in pattern (literal mode)"
# ---------------------------------------------------------------------------

d="$WORKDIR/pipe"
mkdir -p "$d"
echo "a|b|c" > "$d/f.txt"
bash "$SCRIPT" -l "a|b" "X" "$d/f.txt"
assert_file_contains    "$d/f.txt" "X|c"  "literal pipe in pattern"
assert_file_not_contains "$d/f.txt" "a|b"  "original pipe pattern removed"

# ---------------------------------------------------------------------------
section "Multiline file: only matching lines changed"
# ---------------------------------------------------------------------------

d="$WORKDIR/multiline"
mkdir -p "$d"
printf "keep me\nchange me\nkeep me too\n" > "$d/f.txt"
bash "$SCRIPT" "change me" "changed" "$d/f.txt"
assert_file_contains "$d/f.txt" "keep me"    "multiline: non-matching lines kept"
assert_file_contains "$d/f.txt" "keep me too" "multiline: second non-matching line kept"
assert_file_contains "$d/f.txt" "changed"     "multiline: matching line changed"

# ---------------------------------------------------------------------------
section "Binary files skipped by extension"
# ---------------------------------------------------------------------------

d="$WORKDIR/binary_ext"
mkdir -p "$d"
echo "replace me" > "$d/audio.mp3"
echo "replace me" > "$d/video.mp4"
echo "replace me" > "$d/sound.wav"
echo "replace me" > "$d/image.PNG"
echo "replace me" > "$d/document.pdf"
echo "replace me" > "$d/text.txt"

bash "$SCRIPT" -r "replace me" "replaced" "$d"
assert_file_contains    "$d/audio.mp3"    "replace me" "binary exclusion: .mp3 skipped"
assert_file_contains    "$d/video.mp4"    "replace me" "binary exclusion: .mp4 skipped"
assert_file_contains    "$d/sound.wav"    "replace me" "binary exclusion: .wav skipped"
assert_file_contains    "$d/image.PNG"    "replace me" "binary exclusion: case-insensitive .PNG skipped"
assert_file_contains    "$d/document.pdf" "replace me" "binary exclusion: .pdf skipped"
assert_file_contains    "$d/text.txt"     "replaced"   "binary exclusion: text.txt processed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf "${C_BOLD}══════════════════════════════════════════${C_RESET}\n"
printf "${C_BOLD}Results:${C_RESET} "
printf "${C_GREEN}%d passed${C_RESET}, " "$PASS"
printf "${C_RED}%d failed${C_RESET}, " "$FAIL"
printf "${C_YELLOW}%d skipped${C_RESET}\n" "$SKIP"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
