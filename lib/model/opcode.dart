/// Every distinct calculator action a keystroke program can record.
///
/// This is the shared vocabulary between the main keypad (see
/// `lib/ui/keypad.dart`'s per-opcode key table) and [ProgramStep]s: each key
/// on the calculator maps to exactly one [Opcode], so recording is just
/// "append the opcode the user tapped."
///
/// Control-flow (`lbl`/`gto`/`gsb`/`rtn`) and the 12 comparison tests only
/// make sense inside a program — they have no corresponding live keypad key,
/// they're entered via the program editor's own mini-keypad.
enum Opcode {
  // number entry
  digit,
  decimalPoint,
  enterExponent,
  changeSign,
  backspace,

  // stack control
  enter,
  swapXY,
  rollDown,
  rollUp,
  lastX,
  clearX,
  clearAll,

  // memory
  store,
  recall,

  // constants
  pi,
  eConst,

  // arithmetic
  add,
  subtract,
  multiply,
  divide,
  power,
  root,
  percent,
  percentChange,

  // unary
  reciprocal,
  sqrt,
  square,
  log10,
  ln,
  tenToX,
  eToX,
  sin,
  cos,
  tan,
  asin,
  acos,
  atan,
  factorial,

  // program-only control flow
  lbl,
  gto,
  gsb,
  rtn,

  // program-only conditional tests (HP-41 semantics: false skips next line)
  xEq0,
  xNe0,
  xGt0,
  xLt0,
  xGe0,
  xLe0,
  xEqY,
  xNeY,
  xGtY,
  xLtY,
  xGeY,
  xLeY,
}

/// Whether [op] is a comparison test (used by [ProgramEngine] to decide
/// skip-next-line semantics rather than invoking an engine action).
bool isTestOpcode(Opcode op) => switch (op) {
  Opcode.xEq0 ||
  Opcode.xNe0 ||
  Opcode.xGt0 ||
  Opcode.xLt0 ||
  Opcode.xGe0 ||
  Opcode.xLe0 ||
  Opcode.xEqY ||
  Opcode.xNeY ||
  Opcode.xGtY ||
  Opcode.xLtY ||
  Opcode.xGeY ||
  Opcode.xLeY => true,
  _ => false,
};

/// Whether [op] is control flow (`LBL`/`GTO`/`GSB`/`RTN`) rather than a
/// calculator action.
bool isControlFlowOpcode(Opcode op) => switch (op) {
  Opcode.lbl || Opcode.gto || Opcode.gsb || Opcode.rtn => true,
  _ => false,
};
