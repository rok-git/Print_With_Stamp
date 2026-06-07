# Print With Stamp

<p align="center">
  <img src="docs/images/logo.png" alt="Print With Stamp logo" width="220">
</p>

A small macOS CLI tool for adding stamps to PDFs and printing them with the `lp` command only when requested.

It can be used for common stamps such as `CONFIDENTIAL`, `APPROVED`, or `REVIEWED`.

## Features

- Add a stamp to every page, only the first page, or selected pages
- Configure stamp text, position, size, opacity, rotation, and margin
- Save the stamped PDF, or send it to the printer
- Pass printer names and print options to macOS `lp`
- Shortcuts for monochrome/color and one-sided/two-sided printing
- Support printer-specific `lp -o` options
- Use a Finder Quick Action helper script with a config file

## Requirements

- macOS
- Swift 5.9 or later
- `lp` command

`lp` is normally included with macOS. If no default printer is configured, specify one with `--printer`.

## Build

```sh
swift build
```

## Install

For regular use, build the release binary and copy it to a directory in your `PATH`.

```sh
swift build -c release
mkdir -p ~/bin
cp .build/release/print-with-stamp ~/bin/
```

If `~/bin` is not in your `PATH`, add it to your shell configuration. For zsh:

```sh
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

After installation, you can run the command without `swift run`.

```sh
print-with-stamp input.pdf --stamp "CONFIDENTIAL" --output stamped.pdf
```

To install it system-wide, copy it to a directory such as `/usr/local/bin` with administrator privileges.

```sh
sudo cp .build/release/print-with-stamp /usr/local/bin/
```

If you want to use it from a Finder Quick Action, it is also useful to copy the helper script to a directory in your `PATH`.

```sh
cp scripts/print-with-stamp-finder.sh ~/bin/print-with-stamp-finder.sh
```

## Usage

Save a stamped PDF:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --stamp-size 52 \
  --output stamped.pdf
```

Use a different stamp position:

```sh
swift run print-with-stamp input.pdf \
  --stamp "REVIEWED" \
  --position bottom-right \
  --output stamped.pdf
```

Select target pages:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --pages 1,3,5-7 \
  --output stamped.pdf
```

Print the stamped PDF:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print
```

Print to a specific printer:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --printer "Printer Name"
```

Print in monochrome and one-sided mode:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --color monochrome \
  --sides one-sided
```

Create the stamped PDF without printing:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --output stamped.pdf \
  --dry-run
```

## Stamp Example

| Before | After |
| --- | --- |
| ![Before stamp](docs/images/sample-before.png) | ![After stamp](docs/images/sample-after.png) |

## Options

- `--stamp TEXT`: Stamp text. Default: `STAMP`
- `--print`: Send the stamped PDF to `lp`
- `--printer NAME`: Printer name passed to `lp -d`
- `--print-option OPTION`: Print option passed as `lp -o OPTION`. Repeatable
- `--color MODE`: `auto`, `color`, `monochrome`
- `--sides MODE`: `auto`, `one-sided`, `two-sided-long-edge`, `two-sided-short-edge`
- `--output PATH`: Path to save the stamped PDF
- `--position NAME`: `center`, `top-left`, `top-right`, `bottom-left`, `bottom-right`
- `--pages PAGES`: Target pages. `all`, `first`, or ranges such as `1,3,5-7`. Default: `all`
- `--stamp-size POINTS`: Stamp font size. If omitted, it is calculated from the page size
- `--opacity VALUE`: `0.0` to `1.0`
- `--rotation DEGREES`: Stamp rotation angle
- `--margin POINTS`: Margin from the page edge
- `--dry-run`: Create the PDF but do not print
- `--help`: Show help

`--output` specifies where to save the stamped PDF. Printing only happens when `--print` is specified.

## Config File

`print-with-stamp` itself does not read config files. The Finder Quick Action helper, `scripts/print-with-stamp-finder.sh`, reads a config file and passes those options to `print-with-stamp`.

For example, place the config file at `~/.config/print-with-stamp/options`.

```sh
mkdir -p ~/.config/print-with-stamp
cp examples/options.conf ~/.config/print-with-stamp/options
```

The config file can contain the same options you would pass to the CLI. Empty lines and lines starting with `#` are ignored. Quoted values are supported.

```sh
--stamp "REVIEWED"
--position bottom-right
--stamp-size 22
--print
--print-option ARCMode=CMBW
--sides one-sided
```

If `--print` is included in the config file, the Finder Quick Action will send the stamped PDF to the printer. To avoid accidental printing from normal CLI use, config files are only read by the helper script.

## Finder Quick Action

Here is one way to stamp and print selected PDFs from Finder using fixed options.

1. Install `print-with-stamp`.
2. Create `~/.config/print-with-stamp/options`.
3. Copy `scripts/print-with-stamp-finder.sh` to a path such as `~/bin/print-with-stamp-finder.sh`.
4. Open Automator and create a new Quick Action.
5. Set "Workflow receives current" to "PDF files", and "in" to "Finder.app".
6. Add "Run Shell Script", and set "Pass input" to "as arguments".
7. Enter the following script:

```sh
~/bin/print-with-stamp-finder.sh "$@"
```

Automator may use a different `PATH` from your normal terminal. If the command is not found, use an absolute path to `print-with-stamp` inside `~/bin/print-with-stamp-finder.sh`.

## Printer Options

You can inspect printer-specific options from Terminal:

```sh
lpoptions -p "Printer Name" -l
```

Use `--print-option` to pass printer-specific `lp` options.

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --print-option media=A4 \
  --print-option fit-to-page
```

`--color monochrome` passes `print-color-mode=monochrome` and `ColorModel=Gray` to `lp`. Some printer drivers require different option keys. In that case, inspect `lpoptions -p "Printer Name" -l` and pass the monochrome option with `--print-option`.

For example, if `lpoptions -l` includes:

```text
ARCMode/Color Mode: *CMAuto CMColor CMBW
```

`ARCMode` is the option name and `CMBW` is the monochrome value, so use:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --print-option ARCMode=CMBW
```

`--color` and `--sides` are generic shortcuts, while `--print-option` passes printer-specific values directly. If conflicting options are given at the same time, which one wins depends on the printer driver.

For example, avoid this because the generic option requests color while the printer-specific option requests monochrome:

```sh
swift run print-with-stamp input.pdf \
  --stamp "CONFIDENTIAL" \
  --print \
  --color color \
  --print-option ARCMode=CMBW
```

If you know the printer-specific option, it is safer to omit `--color` and use `--print-option` only.

## Notes

- This tool only adds a visual stamp to PDFs and optionally prints or saves them.
- Check the generated PDF before printing when placement matters.
- Printer options vary by printer driver, especially for color and finishing options.

Example:

```text
CONFIDENTIAL
```

## License

MIT License. See [LICENSE](LICENSE).
