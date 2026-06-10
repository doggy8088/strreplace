# strreplace — 字串／正規表示式取代 CLI 工具

一個強大且可攜式的 Bash 腳本，用於在一個或多個檔案中取代字串或正規表示式模式，支援 Glob 模式與遞迴目錄走訪。

## 安裝

### 一行安裝（推薦）

```bash
curl -fsSL https://raw.githubusercontent.com/doggy8088/strreplace/main/install.sh | bash
```

此指令會自動下載最新版本並安裝至 `$HOME/.local/bin/strreplace`（目錄不存在時會自動建立；若指定其他需要 sudo 的路徑，會自動提示）。

### 手動安裝

```bash
# 複製到 PATH 中的任意位置
cp strreplace.sh /usr/local/bin/strreplace
chmod +x /usr/local/bin/strreplace
```

或直接使用 `bash strreplace.sh ...` 執行。

## 使用方式

```
strreplace [選項] <模式> <取代字串> <檔案|glob> [<檔案|glob> ...]
```

### 位置參數

| 參數 | 說明 |
|---|---|
| `<模式>` | ERE 正規表示式模式（或搭配 `--literal` 使用字面字串） |
| `<取代字串>` | 取代字串；支援捕捉群組（`\1`、`\2`、…） |
| `<檔案\|資料夾\|glob>` | 一個或多個檔案路徑、資料夾或 Glob 模式 |

### 選項

| 旗標 | 說明 |
|---|---|
| `-r, --recursive` | 遞迴進入子目錄 |
| `-n, --dry-run` | 顯示將進行的變更，但不實際修改檔案 |
| `-v, --verbose` | 輸出額外的除錯資訊 |
| `-q, --quiet` | 隱藏所有非錯誤輸出 |
| `-i, --ignore-case` | 不區分大小寫比對 |
| `-l, --literal` | 將模式視為字面字串（不使用正規表示式） |
| `-b, --backup` | 為每個修改的檔案建立備份（預設後綴：`.bak`） |
| `--backup-suffix <後綴>` | 自訂備份檔案後綴 |
| `-c, --confirm` | 在處理每個檔案前詢問確認 |
| `-C, --count` | 印出每個檔案的取代次數 |
| `--max-depth <n>` | 最大遞迴深度（需搭配 `-r` 使用） |
| `--include <glob>` | 僅處理符合 glob 的檔案（例如 `*.txt`） |
| `--exclude <glob>` | 跳過符合 glob 的檔案（例如 `*.min.js`） |
| `--exclude-dir <名稱>` | 跳過符合名稱的目錄（例如 `.git`） |
| `-h, --help` | 顯示說明訊息 |
| `-V, --version` | 印出版本並結束 |

## 取代語法

| 符號 | 意義 |
|---|---|
| `&` | 整個比對結果 |
| `\1` … `\9` | 捕捉群組反向參照（ERE） |

## 範例

```bash
# 在所有 .txt 檔案中將「foo」取代為「bar」
strreplace foo bar *.txt

# 不區分大小寫、遞迴處理，並建立備份
strreplace -r -i -b "hello world" "Hi there" ./src

# 正規表示式：將日期格式 YYYY-MM-DD 重新格式化為 DD-MM-YYYY（使用捕捉群組）
strreplace -r '([0-9]{4})-([0-9]{2})-([0-9]{2})' '\3-\2-\1' ./docs

# 乾跑模式預覽變更而不修改檔案
strreplace -n -r "v[0-9]+\.[0-9]+" "v2.0" .

# 字面字串（特殊正規表示式字元會自動跳脫）
strreplace -l "foo.bar()" "baz.qux()" file.js

# 遞迴處理，搭配多個排除條件與檔案類型篩選
strreplace -r \
  --exclude-dir node_modules \
  --exclude-dir .git \
  --include "*.ts" \
  "OldComponent" "NewComponent" ./src

# URL（模式／取代字串中的斜線可正常使用）
strreplace "http://old-api.com/v1" "https://new-api.com/v2" config.yaml

# 統計每個檔案的取代次數
strreplace -C "TODO" "FIXME" src/**/*.py

# 詳細乾跑模式並顯示差異預覽
strreplace -n -v "old_func" "new_func" lib/*.sh

# 在當前目錄的所有檔案中取代（非遞迴）
strreplace foo bar .

# 遞迴取代當前目錄底下所有檔案
strreplace -r foo bar .
```

## 注意事項

- 使用**延伸正規表示式（ERE）** — 與 `grep -E`／`sed -E` 相同的語法
- 二進位檔案會**自動跳過**
- 內部 sed 分隔符號使用控制字元（`\x01`），因此 `/`、`|`、`#` 等字元在模式與取代字串中**無需跳脫**即可安全使用
- 同時支援 **GNU sed**（Linux）與 **BSD sed**（macOS）
- `--exclude-dir` 可**重複指定**以排除多個目錄

## 執行測試

```bash
bash test_strreplace.sh
```

所有 44 個測試皆應通過（0 個失敗）。
