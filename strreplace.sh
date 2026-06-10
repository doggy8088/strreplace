#!/usr/bin/env bash
# =============================================================================
# strreplace - String/Regex Replace CLI Tool
# =============================================================================
# Replace strings or regex patterns across one or more files.
# Supports glob patterns, recursive directory traversal, dry-run, backups,
# case-insensitive matching, and capture group references.
#
# Usage:
#   strreplace [OPTIONS] <pattern> <replacement> <file|glob> [<file|glob> ...]
#
# See strreplace --help for full documentation.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
# Use a rarely-seen control character (SOH = \x01) as the sed delimiter to
# safely handle patterns/replacements that contain '/', '|', or '#'.
readonly SED_DELIM=$'\x01'

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
OPT_RECURSIVE=false
OPT_DRY_RUN=false
OPT_VERBOSE=false
OPT_QUIET=false
OPT_CASE_INSENSITIVE=false
OPT_BACKUP=false
OPT_BACKUP_SUFFIX=".bak"
OPT_LITERAL=false          # treat pattern as literal string, not regex
OPT_CONFIRM=false          # ask before each file replacement
OPT_MAX_DEPTH=""           # max directory depth (empty = unlimited)
OPT_INCLUDE=""             # only files matching this glob (e.g. "*.txt")
OPT_EXCLUDE=""             # skip files matching this glob (e.g. "*.log")
OPT_EXCLUDE_DIR=""         # skip directories matching this name (e.g. ".git")
OPT_COUNT=false            # print match count per file

PATTERN=""
REPLACEMENT=""
declare -a FILE_ARGS=()

# ---------------------------------------------------------------------------
# Color helpers (auto-disabled when not a tty or NO_COLOR set)
# ---------------------------------------------------------------------------
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
  C_RESET="\033[0m"
  C_BOLD="\033[1m"
  C_DIM="\033[2m"
  C_RED="\033[0;31m"
  C_GREEN="\033[0;32m"
  C_YELLOW="\033[0;33m"
  C_CYAN="\033[0;36m"
  C_MAGENTA="\033[0;35m"
else
  C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN=""
  C_YELLOW="" C_CYAN="" C_MAGENTA=""
fi

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
info()    { [[ "$OPT_QUIET" == "false" ]] && printf "${C_CYAN}[info]${C_RESET}  %s\n" "$*" >&2 || true; }
success() { [[ "$OPT_QUIET" == "false" ]] && printf "${C_GREEN}[ok]${C_RESET}    %s\n" "$*" >&2 || true; }
warn()    { printf "${C_YELLOW}[warn]${C_RESET}  %s\n" "$*" >&2; }
error()   { printf "${C_RED}[error]${C_RESET} %s\n" "$*" >&2; }
verbose() { [[ "$OPT_VERBOSE" == "true" ]] && printf "${C_DIM}[debug]${C_RESET} %s\n" "$*" >&2 || true; }
die()     { error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Usage / Help
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
${C_BOLD}${SCRIPT_NAME}${C_RESET} v${VERSION} — String/Regex Replace CLI Tool

${C_BOLD}USAGE${C_RESET}
  ${SCRIPT_NAME} [OPTIONS] <pattern> <replacement> <file|glob> [<file|glob> ...]

${C_BOLD}POSITIONAL ARGUMENTS${C_RESET}
  <pattern>      ERE regex pattern (or literal string with --literal)
  <replacement>  Replacement string; supports capture groups (\1, \2, ...)
  <file|glob>    One or more file paths or glob patterns

${C_BOLD}OPTIONS${C_RESET}
  ${C_BOLD}-r, --recursive${C_RESET}           Recurse into directories
  ${C_BOLD}-n, --dry-run${C_RESET}             Show what would change, but don't modify files
  ${C_BOLD}-v, --verbose${C_RESET}             Print extra debug information
  ${C_BOLD}-q, --quiet${C_RESET}               Suppress all non-error output
  ${C_BOLD}-i, --ignore-case${C_RESET}         Case-insensitive matching
  ${C_BOLD}-l, --literal${C_RESET}             Treat pattern as a literal string (no regex)
  ${C_BOLD}-b, --backup${C_RESET}              Create a backup of each modified file
  ${C_BOLD}    --backup-suffix <sfx>${C_RESET}  Backup file suffix (default: .bak)
  ${C_BOLD}-c, --confirm${C_RESET}             Ask for confirmation before each file
  ${C_BOLD}-C, --count${C_RESET}               Print number of replacements per file
  ${C_BOLD}    --max-depth <n>${C_RESET}        Maximum recursion depth when using -r
  ${C_BOLD}    --include <glob>${C_RESET}        Only process files matching glob (e.g. "*.txt")
  ${C_BOLD}    --exclude <glob>${C_RESET}        Skip files matching glob     (e.g. "*.min.js")
  ${C_BOLD}    --exclude-dir <name>${C_RESET}   Skip directories named <name> (e.g. ".git")
  ${C_BOLD}-h, --help${C_RESET}                Show this help message
  ${C_BOLD}    --version${C_RESET}              Print version and exit

${C_BOLD}REPLACEMENT SYNTAX${C_RESET}
  &             Entire match (same as \0 in some engines)
  \1 … \9       Capture groups (ERE)
  \\n            Literal newline

${C_BOLD}NOTES${C_RESET}
  • Uses Extended Regular Expressions (ERE, i.e. grep -E / sed -E syntax)
  • Binary files are automatically skipped
  • The pattern delimiter is an internal control character, so '/', '|', '#',
    etc. are safe to use in your pattern and replacement without escaping

${C_BOLD}EXAMPLES${C_RESET}
  # Replace "foo" with "bar" in all .txt files in current directory
  ${SCRIPT_NAME} foo bar *.txt

  # Case-insensitive replacement, recursive, with backup
  ${SCRIPT_NAME} -r -i -b "hello world" "Hi there" ./src

  # Regex: reformat dates from YYYY-MM-DD to DD/MM/YYYY using capture groups
  ${SCRIPT_NAME} -r '([0-9]{4})-([0-9]{2})-([0-9]{2})' '\3/\2/\1' ./docs

  # Dry-run to preview changes without touching files
  ${SCRIPT_NAME} -n -r "v[0-9]+\.[0-9]+" "v2.0" .

  # Replace literal string (special chars not treated as regex)
  ${SCRIPT_NAME} -l "foo.bar()" "baz.qux()" file.js

  # Glob multiple patterns, exclude build dirs
  ${SCRIPT_NAME} -r --exclude-dir node_modules --exclude-dir .git \
    --include "*.ts" "OldComponent" "NewComponent" ./src

  # Count replacements per file
  ${SCRIPT_NAME} -C "TODO" "FIXME" src/**/*.py

  # URLs in pattern/replacement (/ chars are fine)
  ${SCRIPT_NAME} "http://old-domain.com/api" "https://new-domain.com/v2" config.yaml

EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
  local positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--recursive)       OPT_RECURSIVE=true;              shift ;;
      -n|--dry-run)         OPT_DRY_RUN=true;                shift ;;
      -v|--verbose)         OPT_VERBOSE=true;                shift ;;
      -q|--quiet)           OPT_QUIET=true;                  shift ;;
      -i|--ignore-case)     OPT_CASE_INSENSITIVE=true;       shift ;;
      -l|--literal)         OPT_LITERAL=true;                shift ;;
      -b|--backup)          OPT_BACKUP=true;                 shift ;;
      --backup-suffix)      OPT_BACKUP_SUFFIX="$2";          shift 2 ;;
      --backup-suffix=*)    OPT_BACKUP_SUFFIX="${1#*=}";     shift ;;
      -c|--confirm)         OPT_CONFIRM=true;                shift ;;
      -C|--count)           OPT_COUNT=true;                  shift ;;
      --max-depth)          OPT_MAX_DEPTH="$2";              shift 2 ;;
      --max-depth=*)        OPT_MAX_DEPTH="${1#*=}";         shift ;;
      --include)            OPT_INCLUDE="$2";                shift 2 ;;
      --include=*)          OPT_INCLUDE="${1#*=}";           shift ;;
      --exclude)            OPT_EXCLUDE="$2";                shift 2 ;;
      --exclude=*)          OPT_EXCLUDE="${1#*=}";           shift ;;
      --exclude-dir)        OPT_EXCLUDE_DIR="${OPT_EXCLUDE_DIR:+${OPT_EXCLUDE_DIR} }$2"; shift 2 ;;
      --exclude-dir=*)      OPT_EXCLUDE_DIR="${OPT_EXCLUDE_DIR:+${OPT_EXCLUDE_DIR} }${1#*=}"; shift ;;
      -h|--help)            usage; exit 0 ;;
      --version)            echo "${SCRIPT_NAME} v${VERSION}"; exit 0 ;;
      --)                   shift; positional+=("$@"); break ;;
      -*)                   die "Unknown option: $1  (try --help)" ;;
      *)                    positional+=("$1"); shift ;;
    esac
  done

  if [[ ${#positional[@]} -lt 3 ]]; then
    error "Not enough arguments. Need: <pattern> <replacement> <file|glob> ..."
    echo ""
    usage
    exit 1
  fi

  PATTERN="${positional[0]}"
  REPLACEMENT="${positional[1]}"
  FILE_ARGS=("${positional[@]:2}")
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
SED_FLAVOR="bsd"
check_deps() {
  local missing=()
  for cmd in sed grep; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "Missing required commands: ${missing[*]}"

  # Detect sed flavour (BSD/macOS vs GNU)
  if sed --version &>/dev/null 2>&1; then
    SED_FLAVOR="gnu"
  else
    SED_FLAVOR="bsd"
  fi
  verbose "sed flavour: ${SED_FLAVOR}"
}

# ---------------------------------------------------------------------------
# Escape a string for use as a literal sed pattern (ERE)
# ---------------------------------------------------------------------------
escape_literal_pattern() {
  local s="$1"
  # Escape ERE metacharacters that have special meaning in patterns:
  # . * + ? [ ] ^ $ { } ( ) | \
  # We also need to escape our delimiter (SED_DELIM / \x01) but that's
  # essentially impossible to appear in user input, so we skip it.
  printf '%s' "$s" | sed 's/[.[\*^$+?{}()|\\]/\\&/g'
}

# Escape replacement string (& and \ are special in sed replacement)
escape_literal_replacement() {
  local s="$1"
  printf '%s' "$s" | sed 's/[&\]/\\&/g'
}

# ---------------------------------------------------------------------------
# Build the sed expression using SED_DELIM as delimiter
# ---------------------------------------------------------------------------
build_sed_expr() {
  local pattern="$1"
  local replacement="$2"

  if [[ "$OPT_LITERAL" == "true" ]]; then
    pattern="$(escape_literal_pattern "$pattern")"
    replacement="$(escape_literal_replacement "$replacement")"
  fi

  # Flags: g = global, I = case-insensitive (works on both GNU and BSD sed with -E)
  local flags="g"
  if [[ "$OPT_CASE_INSENSITIVE" == "true" ]]; then
    flags="Ig"
  fi

  # Use SED_DELIM (\x01) so that '/', '|', '#' in patterns are safe
  printf 's%s%s%s%s%s' \
    "$SED_DELIM" "$pattern" "$SED_DELIM" "$replacement" "${SED_DELIM}${flags}"
}

# ---------------------------------------------------------------------------
# Glob matching helper (portable via case)
# ---------------------------------------------------------------------------
matches_glob() {
  local name="$1"
  local pattern="$2"
  case "$name" in
    $pattern) return 0 ;;
    *)        return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Collect all target files from FILE_ARGS
# ---------------------------------------------------------------------------
declare -a TARGET_FILES=()

collect_files() {
  local arg path
  for arg in "${FILE_ARGS[@]}"; do
    # Use eval to allow shell glob expansion in arg
    local -a expanded=()
    while IFS= read -r -d '' f; do
      expanded+=("$f")
    done < <(eval 'for p in '"$arg"'; do [[ -e "$p" ]] && printf "%s\0" "$p"; done' 2>/dev/null || true)

    if [[ ${#expanded[@]} -eq 0 ]]; then
      warn "No match for: $arg"
      continue
    fi

    for path in "${expanded[@]}"; do
      if [[ -d "$path" ]]; then
        if [[ "$OPT_RECURSIVE" == "true" ]]; then
          collect_dir "$path" 0
        else
          warn "Skipping directory (use -r to recurse): $path"
        fi
      elif [[ -f "$path" ]]; then
        add_file_if_eligible "$path"
      fi
    done
  done
}

collect_dir() {
  local dir="$1"
  local depth="$2"

  # Max depth check
  if [[ -n "$OPT_MAX_DEPTH" ]] && [[ "$depth" -ge "$OPT_MAX_DEPTH" ]]; then
    verbose "Max depth reached at: $dir"
    return
  fi

  local entry
  for entry in "$dir"/.[!.]* "$dir"/*; do
    [[ -e "$entry" ]] || continue

    local base
    base="$(basename "$entry")"

    if [[ -d "$entry" ]]; then
      # Check --exclude-dir (supports multiple space-separated names)
      if [[ -n "$OPT_EXCLUDE_DIR" ]]; then
        local excl
        for excl in $OPT_EXCLUDE_DIR; do
          if matches_glob "$base" "$excl"; then
            verbose "Skipping excluded dir: $entry"
            continue 2
          fi
        done
      fi
      collect_dir "$entry" $((depth + 1))
    elif [[ -f "$entry" ]]; then
      add_file_if_eligible "$entry"
    fi
  done
}

add_file_if_eligible() {
  local file="$1"
  local base
  base="$(basename "$file")"

  # --include filter
  if [[ -n "$OPT_INCLUDE" ]]; then
    local incl matched=false
    for incl in $OPT_INCLUDE; do
      if matches_glob "$base" "$incl"; then
        matched=true
        break
      fi
    done
    if [[ "$matched" == "false" ]]; then
      verbose "Skipping (not included): $file"
      return
    fi
  fi

  # --exclude filter
  if [[ -n "$OPT_EXCLUDE" ]]; then
    local excl
    for excl in $OPT_EXCLUDE; do
      if matches_glob "$base" "$excl"; then
        verbose "Skipping (excluded): $file"
        return
      fi
    done
  fi

  # Must be readable
  if [[ ! -r "$file" ]]; then
    warn "Not readable, skipping: $file"
    return
  fi

  # Skip binary files
  if is_binary "$file"; then
    verbose "Skipping binary file: $file"
    return
  fi

  TARGET_FILES+=("$file")
}

# Heuristic binary detection
is_binary() {
  local file="$1"

  # Ignore common binary file extensions (case-insensitive)
  if [[ "$file" == *.* ]]; then
    local ext="${file##*.}"
    local ext_lower
    ext_lower="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    case "$ext_lower" in
      # Audio & Video
      mp3|mp4|wav|mkv|avi|flac|ogg|mov|webm|aac|m4a)
        return 0
        ;;
      # Images
      png|jpg|jpeg|gif|webp|bmp|ico|tiff)
        return 0
        ;;
      # Archives & Compressed files
      zip|tar|gz|tgz|bz2|rar|7z|xz|dmg|iso)
        return 0
        ;;
      # Executables, Libraries & Object files
      exe|dll|so|dylib|class|bin|o|a|pyc)
        return 0
        ;;
      # Documents
      pdf|docx|xlsx|pptx)
        return 0
        ;;
      # Fonts
      ttf|otf|woff|woff2|eot)
        return 0
        ;;
    esac
  fi

  if command -v file &>/dev/null; then
    local mime
    mime="$(file --mime-encoding -b "$file" 2>/dev/null || true)"
    [[ "$mime" == "binary" ]] && return 0
  fi
  # Fallback: check for null bytes in first 8 KB
  if LC_ALL=C grep -qP '\x00' "$file" 2>/dev/null; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Count matches in a file (total occurrences, not just lines)
# ---------------------------------------------------------------------------
count_matches() {
  local file="$1"
  local grep_pattern="$PATTERN"
  if [[ "$OPT_LITERAL" == "true" ]]; then
    grep_pattern="$(escape_literal_pattern "$grep_pattern")"
  fi

  local grepflags=("-E" "-o")
  [[ "$OPT_CASE_INSENSITIVE" == "true" ]] && grepflags+=("-i")

  grep "${grepflags[@]}" "$grep_pattern" "$file" 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# Apply sed expression to a file (in-place)
# ---------------------------------------------------------------------------
apply_sed_inplace() {
  local file="$1"
  local expr="$2"

  if [[ "$SED_FLAVOR" == "gnu" ]]; then
    sed -E -i "$expr" "$file"
  else
    # BSD sed requires an explicit extension arg for -i; use '' for no backup
    sed -E -i '' "$expr" "$file"
  fi
}

# Apply sed expression to a file, writing output to another file (for dry-run)
apply_sed_to_file() {
  local file="$1"
  local expr="$2"
  local out="$3"
  sed -E "$expr" "$file" > "$out"
}

# ---------------------------------------------------------------------------
# Process a single file
# ---------------------------------------------------------------------------
TOTAL_FILES_MODIFIED=0
TOTAL_REPLACEMENTS=0

process_file() {
  local file="$1"
  local sed_expr="$2"

  verbose "Checking: $file"

  # Quick presence check using grep (faster than running sed on no-match files)
  local grep_pattern="$PATTERN"
  if [[ "$OPT_LITERAL" == "true" ]]; then
    grep_pattern="$(escape_literal_pattern "$grep_pattern")"
  fi
  local grepflags=("-E" "-q")
  [[ "$OPT_CASE_INSENSITIVE" == "true" ]] && grepflags+=("-i")

  if ! grep "${grepflags[@]}" "$grep_pattern" "$file" 2>/dev/null; then
    verbose "No match in: $file"
    return
  fi

  local count=0
  if [[ "$OPT_COUNT" == "true" ]] || [[ "$OPT_VERBOSE" == "true" ]]; then
    count=$(count_matches "$file")
  fi

  # Interactive confirm
  if [[ "$OPT_CONFIRM" == "true" ]]; then
    local reply count_hint=""
    [[ $count -gt 0 ]] && count_hint=" (${count} match(es))"
    printf "${C_MAGENTA}[confirm]${C_RESET} Modify ${C_BOLD}%s${C_RESET}%s? [y/N] " \
      "$file" "$count_hint"
    read -r reply </dev/tty
    case "$reply" in
      [yY]|[yY][eE][sS]) ;;
      *) info "Skipped: $file"; return ;;
    esac
  fi

  if [[ "$OPT_DRY_RUN" == "true" ]]; then
    local count_hint=""
    [[ "$OPT_COUNT" == "true" ]] && count_hint=" ${C_DIM}(${count} replacement(s))${C_RESET}"
    printf "${C_YELLOW}[dry-run]${C_RESET} Would modify: ${C_BOLD}%s${C_RESET}%b\n" \
      "$file" "$count_hint"
    # Show diff preview if diff is available
    if command -v diff &>/dev/null; then
      local tmp
      tmp="$(mktemp)"
      apply_sed_to_file "$file" "$sed_expr" "$tmp"
      diff -u "$file" "$tmp" 2>/dev/null || true
      rm -f "$tmp"
    fi
    return
  fi

  # Backup original if requested
  if [[ "$OPT_BACKUP" == "true" ]]; then
    local backup_path="${file}${OPT_BACKUP_SUFFIX}"
    cp -- "$file" "$backup_path"
    verbose "Backed up to: $backup_path"
  fi

  # Apply replacement in-place
  apply_sed_inplace "$file" "$sed_expr"

  local count_hint=""
  [[ "$OPT_COUNT" == "true" ]] && count_hint=" ${C_DIM}(${count} replacement(s))${C_RESET}"
  [[ "$OPT_QUIET" == "false" ]] && \
    printf "${C_GREEN}[modified]${C_RESET} ${C_BOLD}%s${C_RESET}%b\n" "$file" "$count_hint"

  TOTAL_FILES_MODIFIED=$((TOTAL_FILES_MODIFIED + 1))
  TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + count))
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"
  check_deps

  verbose "Pattern:     ${PATTERN}"
  verbose "Replacement: ${REPLACEMENT}"
  verbose "Files:       ${FILE_ARGS[*]}"
  verbose "Recursive:   ${OPT_RECURSIVE}"
  verbose "Dry-run:     ${OPT_DRY_RUN}"
  verbose "Literal:     ${OPT_LITERAL}"
  verbose "Case-ins:    ${OPT_CASE_INSENSITIVE}"
  verbose "Backup:      ${OPT_BACKUP}"
  [[ -n "$OPT_INCLUDE"     ]] && verbose "Include:     ${OPT_INCLUDE}"
  [[ -n "$OPT_EXCLUDE"     ]] && verbose "Exclude:     ${OPT_EXCLUDE}"
  [[ -n "$OPT_EXCLUDE_DIR" ]] && verbose "Excl dirs:   ${OPT_EXCLUDE_DIR}"
  [[ -n "$OPT_MAX_DEPTH"   ]] && verbose "Max depth:   ${OPT_MAX_DEPTH}"

  collect_files

  if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
    warn "No eligible files found."
    exit 0
  fi

  verbose "Files to process: ${#TARGET_FILES[@]}"

  local sed_expr
  sed_expr="$(build_sed_expr "$PATTERN" "$REPLACEMENT")"
  verbose "Sed expression: ${sed_expr}"

  for file in "${TARGET_FILES[@]}"; do
    process_file "$file" "$sed_expr"
  done

  # Summary line
  if [[ "$OPT_QUIET" == "false" ]]; then
    echo ""
    local dry_pfx=""
    [[ "$OPT_DRY_RUN" == "true" ]] && dry_pfx="${C_YELLOW}[dry-run] ${C_RESET}"
    local verb="modified"
    [[ "$OPT_DRY_RUN" == "true" ]] && verb="would be modified"
    local count_str=""
    [[ "$OPT_COUNT" == "true" ]] && count_str=", ${TOTAL_REPLACEMENTS} total replacement(s)"
    printf "%b${C_BOLD}Summary:${C_RESET} %d file(s) %s%s\n" \
      "$dry_pfx" "$TOTAL_FILES_MODIFIED" "$verb" "$count_str"
  fi
}

main "$@"
