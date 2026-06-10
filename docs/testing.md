# 測試文件

本文件說明 `strreplace` 的測試套件架構、測試涵蓋範圍，以及如何執行測試。

## 執行測試

```bash
bash test_strreplace.sh
```

所有 44 個測試皆應通過（0 個失敗）。

## 測試套件架構

測試套件位於 [`test_strreplace.sh`](../test_strreplace.sh)，以純 Bash 撰寫，無需任何外部依賴。

### 輔助函式

| 函式 | 說明 |
|---|---|
| `pass <label>` | 記錄一個通過的測試並印出綠色 ✓ |
| `fail <label>` | 記錄一個失敗的測試並印出紅色 ✗ |
| `skip <label>` | 記錄一個略過的測試並印出黃色 ~ |
| `assert_file_contains <file> <expected> <label>` | 斷言檔案內容包含指定字串 |
| `assert_file_not_contains <file> <unexpected> <label>` | 斷言檔案內容不包含指定字串 |
| `assert_exit_code <actual> <expected> <label>` | 斷言程式結束碼符合預期 |

每個測試群組使用獨立的暫存目錄（位於 `mktemp -d` 建立的工作區），並在測試結束後自動清除。

---

## 測試群組

### 1. Basic string replacement（基本字串取代）

驗證最基礎的功能：在單一檔案中將一個字串取代為另一個字串。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 1 | `simple word replacement` | 目標字串已成功取代 |
| 2 | `original word removed` | 原始字串不再存在於檔案中 |

```bash
bash strreplace.sh "world" "earth" file.txt
```

---

### 2. Regex replacement — ERE（正規表示式取代）

驗證延伸正規表示式（ERE）的取代功能，包含捕捉群組。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 3 | `version regex replacement` | `v[0-9]+\.[0-9]+\.[0-9]+` 成功比對並取代版本號 |
| 4 | `capture group reorder` | `\3-\2-\1` 反向參照將 `YYYY-MM-DD` 重排為 `DD-MM-YYYY` |

```bash
bash strreplace.sh 'v[0-9]+\.[0-9]+\.[0-9]+' 'v9.9.9' ver.txt
bash strreplace.sh '([0-9]{4})-([0-9]{2})-([0-9]{2})' '\3-\2-\1' date.txt
```

---

### 3. Multiple files via glob（Glob 多檔案）

驗證同時對多個檔案（透過 shell glob 展開）執行取代。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 5 | `glob replacement in a.txt` | a.txt 已取代 |
| 6 | `glob replacement in b.txt` | b.txt 已取代 |
| 7 | `glob replacement in c.txt` | c.txt 已取代 |

```bash
bash strreplace.sh "old_value" "new_value" *.txt
```

---

### 4. Recursive flag `-r`（遞迴旗標）

驗證 `-r` / `--recursive` 旗標能深入子目錄遞迴處理檔案。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 8 | `recursive: root` | 根目錄的檔案已取代 |
| 9 | `recursive: sub` | 第一層子目錄的檔案已取代 |
| 10 | `recursive: deep` | 深層子目錄的檔案已取代 |

```bash
bash strreplace.sh -r "find me" "found" ./dir
```

---

### 5. Dry-run `-n`（乾跑模式）

驗證 `-n` / `--dry-run` 旗標只顯示差異，不實際修改檔案。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 11 | `dry-run: file not modified` | 原始內容仍存在 |
| 12 | `dry-run: new content absent` | 新內容不存在於檔案中 |

```bash
bash strreplace.sh -n "original" "changed" file.txt
```

---

### 6. Case-insensitive matching `-i`（不區分大小寫）

驗證 `-i` / `--ignore-case` 旗標能比對任何大小寫組合。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 13 | `case-insensitive: all replaced` | `Hello` 和 `hello` 均被取代 |
| 14 | `case-insensitive: original gone` | 原始大寫字串已移除 |

```bash
bash strreplace.sh -i "hello" "hi" file.txt
# "Hello WORLD hello" → "hi WORLD hi"
```

---

### 7. Literal flag `-l`（字面字串模式）

驗證 `-l` / `--literal` 旗標將正規表示式特殊字元（如 `.`、`(`、`)`）視為一般字元。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 15 | `literal: metacharacters escaped` | `foo.bar()` 被精確比對並取代，不被當成 regex |

```bash
bash strreplace.sh -l "foo.bar()" "baz.qux()" file.js
```

---

### 8. Backup flag `-b`（備份旗標）

驗證 `-b` / `--backup` 旗標在修改前自動建立備份檔案，並支援自訂後綴。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 16 | `backup: file modified` | 原始檔案已取代為新內容 |
| 17 | `backup: .bak file created` | `.bak` 備份檔案存在且保有原始內容 |
| 18 | `backup: custom suffix .orig` | `--backup-suffix .orig` 建立 `.orig` 備份 |

```bash
bash strreplace.sh -b "original" "changed" file.txt
bash strreplace.sh -b --backup-suffix ".orig" "data" "info" file.txt
```

---

### 9. `--include` filter（包含篩選）

驗證 `--include <glob>` 只處理符合 glob 的檔案類型。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 19 | `include: .txt replaced` | 符合 `*.txt` 的檔案已取代 |
| 20 | `include: .md skipped` | `.md` 檔案未被處理 |
| 21 | `include: .sh skipped` | `.sh` 檔案未被處理 |

```bash
bash strreplace.sh -r --include "*.txt" "old" "new" ./dir
```

---

### 10. `--exclude` filter（排除篩選）

驗證 `--exclude <glob>` 跳過符合 glob 的檔案。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 22 | `exclude: a.txt replaced` | 一般 `.txt` 檔案已取代 |
| 23 | `exclude: .min.js skipped` | 符合 `*.min.js` 的檔案被跳過 |

```bash
bash strreplace.sh -r --exclude "*.min.js" "old" "new" ./dir
```

---

### 11. `--exclude-dir` filter（排除目錄）

驗證 `--exclude-dir <name>` 在遞迴時跳過指定名稱的目錄。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 24 | `exclude-dir: src processed` | `src/` 目錄下的檔案已取代 |
| 25 | `exclude-dir: .git skipped` | `.git/` 目錄完全未被處理 |

```bash
bash strreplace.sh -r --exclude-dir ".git" "old" "new" ./dir
```

---

### 12. `--max-depth`（最大遞迴深度）

驗證 `--max-depth <n>` 限制遞迴深度，深度超過 n 的目錄不會被處理。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 26 | `max-depth: depth-0 file modified` | 深度 0 的檔案已取代 |
| 27 | `max-depth: depth-1 file skipped` | 深度 1 的檔案未被處理 |
| 28 | `max-depth: depth-2 file skipped` | 深度 2 的檔案未被處理 |

```bash
bash strreplace.sh -r --max-depth 1 "old" "new" ./l1
```

---

### 13. Multiple replacements on same line（同行多次取代）

驗證同一行中出現多次的模式均會被全部取代（全域取代，非僅第一個）。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 29 | `global replace on same line` | `aaa bbb aaa` → `zzz bbb zzz`（兩個 `aaa` 均取代） |

---

### 14. No match（無比對結果）

驗證當模式在檔案中找不到時，檔案保持不變。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 30 | `no match: file unchanged` | 原始內容仍存在 |
| 31 | `no match: replacement absent` | 取代字串不存在於檔案中 |

---

### 15. `--version` flag（版本旗標）

驗證 `--version`（或 `-V`）輸出符合 `vX.Y.Z` 格式的版本字串。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 32 | `--version outputs version string` | 輸出包含語意化版本號 |

```bash
bash strreplace.sh --version
# strreplace v1.0.0
bash strreplace.sh -V
# strreplace v1.0.0
```

---

### 16. Error handling: no args（無參數的錯誤處理）

驗證未傳入任何引數時程式以退出碼 `1` 結束。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 33 | `exits 1 with no arguments` | 退出碼為 `1` |

---

### 17. Error handling: nonexistent file（不存在檔案的錯誤處理）

驗證指定不存在的檔案時，程式顯示警告訊息而非靜默失敗。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 34 | `warns on nonexistent file` | 輸出包含警告關鍵字（`no match`、`not found`、`warn` 等） |

---

### 18. URLs with slashes（含斜線的 URL）

驗證模式與取代字串中包含 `/` 時能正確運作（內部使用 `\x01` 作為 sed 分隔符號）。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 35 | `URL replacement with slashes` | 新 URL 已正確寫入 |
| 36 | `old URL removed` | 舊 URL 不再存在 |

```bash
bash strreplace.sh "http://old-api.example.com/v1" "https://new-api.example.com/v2" config.txt
```

---

### 19. `--count` flag `-C`（計數旗標）

驗證 `-C` / `--count` 旗標輸出每個檔案的取代次數。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 37 | `--count: reports 3 replacements` | 輸出包含數字 `3` |

```bash
printf "foo\nfoo\nfoo\n" > f.txt
bash strreplace.sh -C "foo" "bar" f.txt
# → 3
```

---

### 20. `--quiet` flag `-q`（靜默旗標）

驗證 `-q` / `--quiet` 旗標抑制所有非錯誤輸出，但仍正常修改檔案。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 38 | `quiet: file still modified` | 檔案內容確實已被取代 |
| 39 | `quiet: no output printed` | stdout + stderr 均無輸出 |

---

### 21. Pipe character in literal mode（字面模式中的管道字元）

驗證 `-l` 模式下，`|` 字元被視為普通字元而非 ERE 的 OR 運算子。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 40 | `literal pipe in pattern` | `a|b` 被精確比對（而非 `a` 或 `b`） |
| 41 | `original pipe pattern removed` | 原始 `a|b` 已移除 |

```bash
# "a|b|c" → "X|c"
bash strreplace.sh -l "a|b" "X" file.txt
```

---

### 22. Multiline file（多行檔案）

驗證只有符合條件的行被修改，其他行保持不變。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 42 | `multiline: non-matching lines kept` | 第一個非比對行保留 |
| 43 | `multiline: second non-matching line kept` | 第二個非比對行保留 |
| 44 | `multiline: matching line changed` | 比對行已取代 |

---

### 23. Binary files skipped（二進位檔案略過）

驗證已知二進位副檔名（`.mp3`、`.mp4`、`.wav`、`.png`、`.pdf` 等）的檔案自動略過，不進行取代。

> **注意：** 副檔名比對不區分大小寫（`.PNG` 和 `.png` 均會被略過）。

| # | 測試描述 | 驗證內容 |
|---|---|---|
| 45 | `binary exclusion: .mp3 skipped` | `.mp3` 未被處理 |
| 46 | `binary exclusion: .mp4 skipped` | `.mp4` 未被處理 |
| 47 | `binary exclusion: .wav skipped` | `.wav` 未被處理 |
| 48 | `binary exclusion: .PNG skipped` | `.PNG`（大寫）未被處理 |
| 49 | `binary exclusion: .pdf skipped` | `.pdf` 未被處理 |
| 50 | `binary exclusion: text.txt processed` | 一般文字檔正常取代 |

---

## 測試總覽

| 群組 | 測試數 |
|---|---|
| 基本字串取代 | 2 |
| 正規表示式（ERE） | 2 |
| Glob 多檔案 | 3 |
| 遞迴旗標 `-r` | 3 |
| 乾跑模式 `-n` | 2 |
| 不區分大小寫 `-i` | 2 |
| 字面字串模式 `-l` | 1 |
| 備份旗標 `-b` | 3 |
| `--include` 篩選 | 3 |
| `--exclude` 篩選 | 2 |
| `--exclude-dir` 篩選 | 2 |
| `--max-depth` 限制 | 3 |
| 同行多次取代 | 1 |
| 無比對結果 | 2 |
| `--version` / `-V` | 1 |
| 無參數錯誤處理 | 1 |
| 不存在檔案警告 | 1 |
| 含斜線的 URL | 2 |
| 計數旗標 `-C` | 1 |
| 靜默旗標 `-q` | 2 |
| 字面管道字元 | 2 |
| 多行檔案 | 3 |
| 二進位檔案略過 | 6 |
| **合計** | **44** |
