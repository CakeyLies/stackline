# RPN Edge Calculator — Plan v2 (from scratch)

An RPN calculator built entirely in Dart/Flutter — no Free42, no native engine, no
GPL. It runs as a normal Android app optimized for Samsung's pop-up view, and is
launched from the built-in **Apps Edge** panel (custom third-party Edge panels are
discontinued, so the app ships as a standard app the user adds to the panel once).

## Goals

- A faithful **RPN** calculator (HP-style 4-level stack: T/Z/Y/X + LASTx).
- **From scratch**: a pure-Dart engine, fully unit-tested, no third-party math
  engines and no native code (nothing to build with the NDK).
- **Custom themes**: multiple swappable color palettes, persisted across launches.
- **Android pop-up view**: runs as a floating, resizable window on Samsung One UI.

## Non-goals (v1)

- No keystroke programmability (SOLVE/INTEG/matrices are out of scope for now).
- No complex-number support (reals only) — revisit later.
- No iOS/desktop — Android only for now.
- Bit-for-bit HP-42S/15C emulation — this is an original implementation, not a clone.

## Decisions

| Topic | Decision | Rationale |
| --- | --- | --- |
| Engine | Pure Dart (`lib/engine/`) | No Free42, no GPL, no NDK build; trivially unit-testable. |
| Decimal math | `decimal` package for stack/arithmetic (exact base-10) | Avoids `0.1 + 0.2 = 0.30000000000000004`. |
| Transcendentals | `dart:math` (double) rounded to display precision | `decimal` has no trig/log; acceptable precision for v1. |
| State | `ChangeNotifier` + Flutter's built-in `ListenableBuilder` | No extra state-management dependency. |
| Theme | Immutable `CalcTheme` model + built-in presets | Simple, type-safe, easily persisted. |
| Persistence | `shared_preferences` | Store selected theme + angle/display prefs. |
| Pop-up view | `android:resizeableActivity="true"` + responsive layout | Samsung pop-up is freeform multi-window; no special API exists to force it. |

## Architecture

```
lib/
├── main.dart                 # app entry, theme + controller wiring
├── engine/
│   ├── engine.dart           # RPN engine: stack, LASTx, registers, entry state
│   ├── operations.dart       # arithmetic + transcendental functions
│   └── display.dart          # number formatting (FIX/SCI/ENG, significant digits)
├── model/
│   └── theme.dart            # CalcTheme data class + built-in presets
├── state/
│   └── calculator_controller.dart   # ChangeNotifier bridging engine <-> UI
└── ui/
    ├── calculator_screen.dart        # responsive layout (compact + full)
    ├── lcd.dart                      # stack display (X/Y/Z/T, LASTx, annunciators)
    ├── keypad.dart                   # key grid -> engine keycodes
    └── theme_picker.dart             # choose/persist a theme
```

## RPN engine spec

**Stack & registers**
- 4-level stack `T Z Y X` with `LASTx`; all entries are `Decimal`.
- 10 general memory registers (`STO n` / `RCL n`, n = 0..9 via keypad) for v1.
- Number entry: digit accumulation, decimal point, `E` (exponent), backspace,
  sign change, and entry-state tracking (typing vs. next-number).

**Core operations**
- Two-operand: `+ − × ÷`, `yˣ` (power), `x√y` (root), `%`, `Δ%`.
- One-operand: `1/x`, `√x`, `x²`, `±`, `n!`, `10ˣ`, `eˣ`, `ln`, `log`.
- Trig: `sin cos tan` + inverses; angle modes DEG / RAD / GRAD.
- Stack control: `ENTER`, `x↔y`, `R↓`, `R↑`, `CLx`, `LASTx`.
- Constants: `π`, `e`.
- Clear: `CLx` (X only) and full clear (stack + registers).

**Precision & display**
- Internal precision ~20 significant digits (`decimal`); display rounds to a
  configurable `FIX`/`SCI`/`ENG` with 0–9 digits (default FIX 4).
- `sqrt` computed on `Decimal` via Newton's method; trig/log/exp via `dart:math`
  with DEG↔RAD conversion, then rounded back to a `Decimal`.

## Themes

`CalcTheme` holds: scaffold background, LCD background/text/border, key
background, key text, function-key color, accent (ENTER key), and a name.

Built-in presets (illustrative): **Classic 42S** (amber/brown LCD),
**Voyager** (dark blue + gold), **Dark OLED**, **Light**, **Terminal green**,
**Solarized**.

- Picker screen lists presets; selection is applied live and saved to
  `shared_preferences`.

## Android pop-up view

- Manifest: `android:resizeableActivity="true"` (already supported by Flutter's
  default `configChanges` handling for size/orientation changes).
- Layout adapts via `LayoutBuilder`/`MediaQuery` — a **compact** layout for small
  pop-up windows and a larger layout when full-screen.
- **How the user opens it**: from the Apps Edge panel, **drag** the app icon out
  onto the screen (a tap opens full screen); or Recents → tap the app icon →
  "Open in pop-up view". There is no public API to force pop-up mode — it's a
  system gesture, so the app just needs to *support* it.
- Verify/remove the generated `android:taskAffinity=""` if it interferes with
  freeform recents behavior during on-device testing.

## Dependencies

- `decimal` — arbitrary-precision base-10 arithmetic.
- `shared_preferences` — persist theme + prefs.

(Everything else uses the Flutter SDK; no state-management, math-engine, or
overlay packages.)

## Testing

- **Unit tests** for the engine: stack lift/drop semantics, entry states, every
  operation, DEG/RAD, and decimal exactness (`0.1 + 0.2 == 0.3`).
- **Widget tests**: keypad → engine wiring, LCD formatting, theme switching.

## Milestones

1. Scaffold a fresh Flutter app (Android only); wire `decimal` + `shared_preferences`.
2. Build the engine: stack, entry, arithmetic + stack ops (unit-tested).
3. Transcendentals, powers/roots, constants, memory registers (unit-tested).
4. LCD + keypad UI, number formatting (FIX/SCI/ENG), key→engine mapping.
5. Theme system + picker + persistence.
6. Responsive/pop-up layout polish; on-device verification of Samsung pop-up view.
7. Release build + install; final device pass.
