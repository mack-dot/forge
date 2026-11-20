"use client";

import { useEffect, useState } from "react";

export interface ScriptLine {
  who: string;
  text: string;
  /** Pause after the line, in ms. */
  pause?: number;
  /** Delay per character, in ms. */
  step?: number;
}

/**
 * Types the lines one character at a time. With `instant` (reduced motion) a
 * line appears whole; the lines still arrive one after the other.
 */
export function useTypedScript(lines: readonly ScriptLine[], active: boolean, instant: boolean) {
  const [pos, setPos] = useState({ line: 0, char: 0 });

  useEffect(() => {
    if (!active) return;
    const cur = lines[pos.line];
    if (!cur) return;
    let timer: ReturnType<typeof setTimeout>;
    if (pos.char < cur.text.length) {
      timer = setTimeout(
        () => setPos((p) => ({ line: p.line, char: instant ? cur.text.length : p.char + 1 })),
        instant ? 0 : (cur.step ?? 30),
      );
    } else {
      timer = setTimeout(
        () => setPos((p) => ({ line: p.line + 1, char: 0 })),
        instant ? Math.max(900, cur.pause ?? 0) : (cur.pause ?? 520),
      );
    }
    return () => clearTimeout(timer);
  }, [pos, active, instant, lines]);

  return { line: pos.line, char: pos.char, finished: pos.line >= lines.length };
}
