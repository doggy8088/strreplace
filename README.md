# strreplace — String/Regex Replace CLI Tool

A powerful, portable bash script for replacing strings or regex patterns across
one or more files with glob support and recursive traversal.

## Installation

```bash
# Copy to somewhere on your PATH
cp strreplace.sh /usr/local/bin/strreplace
chmod +x /usr/local/bin/strreplace
```

Or just use it directly with `bash strreplace.sh ...`.

## Usage

```
strreplace [OPTIONS] <pattern> <replacement> <file|glob> [<file|glob> ...]
```

### Positional Arguments

| Argument | Description |
|---|---|
| `<pattern>` | ERE regex pattern (or literal string with `--literal`) |
| `<replacement>` | Replacement string; supports capture groups (`\1`, `\2`, …) |
| `<file\|glob>` | One or more file paths or glob patterns |

### Options

| Flag | Description |
|---|---|
| `-r, --recursive` | Recurse into directories |
| `-n, --dry-run` | Show what would change, but don't modify files |
| `-v, --verbose` | Print extra debug information |
| `-q, --quiet` | Suppress all non-error output |
| `-i, --ignore-case` | Case-insensitive matching |
| `-l, --literal` | Treat pattern as a literal string (no regex) |
| `-b, --backup` | Create a backup of each modified file (default suffix: `.bak`) |
| `--backup-suffix <sfx>` | Custom backup file suffix |
| `-c, --confirm` | Ask for confirmation before each file |
| `-C, --count` | Print number of replacements per file |
| `--max-depth <n>` | Maximum recursion depth (requires `-r`) |
| `--include <glob>` | Only process files matching glob (e.g. `*.txt`) |
| `--exclude <glob>` | Skip files matching glob (e.g. `*.min.js`) |
| `--exclude-dir <name>` | Skip directories matching name (e.g. `.git`) |
| `-h, --help` | Show help message |
| `--version` | Print version and exit |

## Replacement Syntax

| Token | Meaning |
|---|---|
| `&` | Entire match |
| `\1` … `\9` | Capture group back-references (ERE) |

## Examples

```bash
# Replace "foo" with "bar" in all .txt files
strreplace foo bar *.txt

# Case-insensitive, recursive, with backup
strreplace -r -i -b "hello world" "Hi there" ./src

# Regex: reformat dates YYYY-MM-DD → DD-MM-YYYY with capture groups
strreplace -r '([0-9]{4})-([0-9]{2})-([0-9]{2})' '\3-\2-\1' ./docs

# Dry-run to preview changes without modifying files
strreplace -n -r "v[0-9]+\.[0-9]+" "v2.0" .

# Literal string (special regex chars are escaped automatically)
strreplace -l "foo.bar()" "baz.qux()" file.js

# Recursive with multiple exclusions and file-type filter
strreplace -r \
  --exclude-dir node_modules \
  --exclude-dir .git \
  --include "*.ts" \
  "OldComponent" "NewComponent" ./src

# URLs (slashes in pattern/replacement work fine)
strreplace "http://old-api.com/v1" "https://new-api.com/v2" config.yaml

# Count replacements per file
strreplace -C "TODO" "FIXME" src/**/*.py

# Verbose dry-run with diff preview
strreplace -n -v "old_func" "new_func" lib/*.sh
```

## Notes

- Uses **Extended Regular Expressions (ERE)** — the same syntax as `grep -E`/`sed -E`
- Binary files are **automatically skipped**
- The internal sed delimiter is a control character (`\x01`), so `/`, `|`, `#`, etc. are **safe to use** in patterns and replacements without escaping
- Supports both **GNU sed** (Linux) and **BSD sed** (macOS)
- `--exclude-dir` can be specified **multiple times** for multiple exclusions

## Running Tests

```bash
bash test_strreplace.sh
```

All 44 tests should pass (0 failures).
