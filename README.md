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

印刷せずにスタンプ済み PDF だけ確認する場合:

```sh
swift run print-with-stamp input.pdf --stamp "CONFIDENTIAL" --output stamped.pdf --dry-run
```

## Options

- `--stamp TEXT`: スタンプ文字列。デフォルトは `STAMP`
- `--print`: スタンプ済み PDF を `lp` に渡して印刷する
- `--printer NAME`: `lp -d` に渡すプリンタ名
- `--output PATH`: スタンプ済み PDF の保存先
- `--position NAME`: `center`, `top-left`, `top-right`, `bottom-left`, `bottom-right`
- `--pages PAGES`: 対象ページ。`all`, `first`, `1,3,5-7` 形式。未指定時は `all`
- `--stamp-size POINTS`: スタンプ文字のサイズ。未指定時はページサイズから自動計算
- `--opacity VALUE`: `0.0` から `1.0`
- `--rotation DEGREES`: スタンプの回転角度
- `--margin POINTS`: ページ端からの余白
- `--dry-run`: PDF を作るだけで印刷しない
