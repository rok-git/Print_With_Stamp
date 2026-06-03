# Print With Stamp

PDF にスタンプを押した PDF を作り、必要な場合だけ macOS の印刷コマンド `lp` に渡す小さな CLI です。

## Build

```sh
swift build
```

## Usage

```sh
swift run print-with-stamp input.pdf --stamp "CONFIDENTIAL" --stamp-size 52 --output stamped.pdf
```

対象ページを指定する場合:

```sh
swift run print-with-stamp input.pdf --stamp "CONFIDENTIAL" --pages 1,3,5-7 --output stamped.pdf
```

印刷する場合:

```sh
swift run print-with-stamp input.pdf --stamp "CONFIDENTIAL" --print
```

プリンタを指定して印刷する場合:

```sh
swift run print-with-stamp input.pdf --stamp "CONFIDENTIAL" --print --printer "Printer Name"
```

白黒・片面で印刷する場合:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --color monochrome \
  --sides one-sided
```

プリンタ固有の `lp` オプションを指定する場合:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --print-option media=A4 \
  --print-option fit-to-page
```

印刷せずにスタンプ済み PDF だけ確認する場合:

```sh
swift run print-with-stamp input.pdf --stamp "CONFIDENTIAL" --output stamped.pdf --dry-run
```

## Options

- `--stamp TEXT`: スタンプ文字列。デフォルトは `STAMP`
- `--print`: スタンプ済み PDF を `lp` に渡して印刷する
- `--printer NAME`: `lp -d` に渡すプリンタ名
- `--print-option OPTION`: `lp -o OPTION` として渡す印刷オプション。複数指定可
- `--color MODE`: `auto`, `color`, `monochrome`
- `--sides MODE`: `auto`, `one-sided`, `two-sided-long-edge`, `two-sided-short-edge`
- `--output PATH`: スタンプ済み PDF の保存先
- `--position NAME`: `center`, `top-left`, `top-right`, `bottom-left`, `bottom-right`
- `--pages PAGES`: 対象ページ。`all`, `first`, `1,3,5-7` 形式。未指定時は `all`
- `--stamp-size POINTS`: スタンプ文字のサイズ。未指定時はページサイズから自動計算
- `--opacity VALUE`: `0.0` から `1.0`
- `--rotation DEGREES`: スタンプの回転角度
- `--margin POINTS`: ページ端からの余白
- `--dry-run`: PDF を作るだけで印刷しない

プリンタが対応している詳細オプションは macOS のターミナルで確認できます。

```sh
lpoptions -p "Printer Name" -l
```

`--color monochrome` は `print-color-mode=monochrome` と `ColorModel=Gray` を `lp` に渡します。プリンタによっては別のキーが必要なため、その場合は `lpoptions -p "Printer Name" -l` の出力にある白黒指定を `--print-option` で渡してください。

`--color` や `--sides` は汎用的なショートカットで、`--print-option` はプリンタ固有の値を直接渡すための指定です。相反する指定を同時に渡すと、どちらが優先されるかはプリンタドライバ次第です。

例えば、次の指定は汎用オプションではカラー、プリンタ固有オプションでは白黒を指定しているため避けてください。

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --color color \
  --print-option ARCMode=CMBW
```

プリンタ固有の設定が分かっている場合は、`--color` を省いて `--print-option` に寄せるのが安全です。

例えば、`lpoptions -l` に次のような行が出る場合:

```text
ARCMode/Color Mode: *CMAuto CMColor CMBW
```

`ARCMode` がオプション名、`CMBW` が白黒指定なので、次のように指定します。

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --print-option ARCMode=CMBW
```
