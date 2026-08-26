# Stackline

A from-scratch RPN scientific calculator for Android, built entirely in Flutter/Dart —
no Free42, no native engine, no GPL. HP-style 4-level stack (T/Z/Y/X + LASTx), exact
decimal arithmetic, and a display you can reskin on the fly.

Designed to run as a normal Android app optimized for Samsung's floating pop-up view,
launched from the built-in Apps Edge panel.

## Features

- **Full RPN engine** — 4-level stack, `ENTER`, `x⇄y`, roll up/down, `LASTx`, 10 memory
  registers, arithmetic, powers/roots, trig (DEG/RAD/GRAD), logs/exponentials,
  factorial, percent/Δ%.
- **Exact decimal math** — arithmetic uses the `decimal` package so `0.1 + 0.2` is
  exactly `0.3`, not a binary-float approximation.
- **FIX / SCI / ENG display modes** with 0–9 digit precision.
- **Four display styles** — Classic (clean monospace), 7-Segment (LED calculator),
  VFD (glowing vacuum-fluorescent tube look), and Dot Matrix — switchable per theme.
- **Nine color themes**, including a from-scratch "Portal 2" theme with a genuine glow
  effect, plus Cyber Neon, Nixie, Terminal Green, Solarized, and more.
- **Responsive layout** — adapts to compact pop-up windows and landscape orientation
  (side-by-side LCD + keypad instead of squeezing everything into one column).
- **Fully unit- and widget-tested** — engine correctness, every display style, every
  theme, and layout at multiple screen sizes.

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable
channel) and an Android toolchain for on-device builds.

```bash
flutter pub get
flutter run
```

Run the test suite:

```bash
flutter test
```

Build a release APK:

```bash
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Project layout

```
lib/
├── main.dart                 # app entry, theme + controller wiring
├── engine/
│   ├── engine.dart           # RPN engine: stack, LASTx, registers, entry state
│   └── display.dart          # number formatting (FIX/SCI/ENG)
├── model/
│   ├── theme.dart             # CalcTheme data class + built-in presets
│   └── display_style.dart     # display style enum + per-style color resolution
└── ui/
    ├── calculator_screen.dart # responsive layout (portrait + landscape)
    ├── lcd.dart                # stack display (X/Y/Z/T, LASTx, annunciators)
    ├── keypad.dart             # key grid -> engine actions
    ├── segment_display.dart    # 7-segment / VFD / dot-matrix glyph rendering
    └── theme_picker.dart       # theme + display style picker
```

See [PLAN.md](PLAN.md) for the original design notes and roadmap.

## Status

Early releases (`0.0.x`) — core engine and UI are functional and tested, but this is
still a personal project under active development. No complex-number support and no
keystroke programmability yet.
