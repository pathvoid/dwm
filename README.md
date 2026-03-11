# dwm

My personal build of [dwm](https://dwm.suckless.org/) for Arch Linux.

Stripped down and heavily modified to fit my needs - unnecessary features removed, monocle (fullscreen) layout by default, and Alt+Tab window switching for a Windows-like experience.

## Install

```bash
make clean && sudo make install
```

Or use the included script:

```bash
dwm-build-install
```

## Keybindings

See `config.h` for the full list. Key highlights:

- **Alt+Tab** / **Super+Tab** — cycle windows
- **Super+Q** — close window
- **Super+R** — app launcher (rofi)
- **Super+X** — terminal
- **Super+T** — tiled layout
- **Super+M** — fullscreen
- **Super+Shift+Q** — quit dwm
