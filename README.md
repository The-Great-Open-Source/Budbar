# Budbar

A native macOS menu bar app for controlling Soundcore earbuds. Switch between Noise Cancelling, Transparency and Normal, tweak the options for each mode, and see battery levels for each bud and the case, without picking up your phone.

**Status: early development.** Built for the Soundcore R60i NC (and the closely related P31i). It has not been tested on other models. Expect rough edges.

> Unofficial. Not affiliated with, endorsed by, or sponsored by Anker or Soundcore.

## Features

- Lives in the menu bar, opens a compact popover
- Noise Cancelling (Adaptive, Manual with 5 levels, Scenes), Transparency (Fully transparent, Vocal), Normal
- Wind noise reduction toggle
- Left, right and case battery rings
- Keyboard shortcuts: Cmd+1, Cmd+2, Cmd+3 for the three modes
- Optional launch at login
- Demo mode so you can try the UI without earbuds

## Requirements

- macOS 14 or newer
- Swift 5.9+ toolchain (Xcode 15 or newer, or the command line tools)

## Build and run

```sh
swift build        # compile
swift test         # protocol tests
scripts/bundle.sh --open   # build build/Budbar.app and launch it
```

Try the UI without earbuds:

```sh
open build/Budbar.app --args --demo
```

## Connecting

Budbar needs a Bluetooth Classic connection to the earbuds, and the earbuds only accept one controller at a time. If connecting times out, disconnect the earbuds from your phone (or close the Soundcore app there) and press "Try again".

The first launch asks for Bluetooth permission.

## How it works

Soundcore earbuds expose a proprietary protocol over a Bluetooth RFCOMM channel. `SoundcoreProtocol` is a small, dependency free Swift library that frames packets, checks checksums and encodes or decodes the sound mode and battery state. The app target adds an IOBluetooth transport and the SwiftUI interface.

## Credits and license

The protocol knowledge comes from [OpenSCQ30](https://github.com/Oppzippy/OpenSCQ30) by Oppzippy and contributors. Budbar is a Swift port of the relevant parts, so it is licensed under the GNU General Public License v3.0 or later, the same as OpenSCQ30. See `LICENSE` and `NOTICE.md`.
