"""Sound cues of the video cut (Python stdlib only: wave, struct, math). No downloaded audio.

Each cue is synthesized into a WAV file in the take's temp folder. /usr/bin/afplay plays it without
blocking. If afplay is missing, the cue is printed as a `cue| t=<seconds> <name>` line for the editor.
The cue sheet holds the offsets that this run measured from the start of the take.
"""
import json
import math
import os
import struct
import subprocess
import time
import wave

RATE = 22050
PLAYER = '/usr/bin/afplay'


def _tone(freq, seconds, volume, attack=0.01, decay=None, freq_end=None):
    """One sine tone with a linear attack and an exponential decay. freq_end makes a pitch slide."""
    n = int(RATE * seconds)
    decay = decay if decay is not None else seconds / 3
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = freq + (freq_end - freq) * (i / n) if freq_end else freq
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / attack) * math.exp(-t / decay) * min(1.0, (seconds - t) / 0.01)
        out.append(volume * env * math.sin(phase))
    return out


def _silence(seconds):
    return [0.0] * int(RATE * seconds)


def _mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def _hum():  # 55 Hz hum with a weak octave, slow fade in and out
    n = int(RATE * 4.0)
    return [0.45 * min(1.0, i / (RATE * 0.5), (n - i) / (RATE * 0.8))
            * (math.sin(2 * math.pi * 55 * i / RATE) + 0.3 * math.sin(2 * math.pi * 110 * i / RATE)) for i in range(n)]


def _pad():  # soft pad: three slow sines of one chord
    n = int(RATE * 3.0)
    return [0.16 * min(1.0, i / (RATE * 0.8), (n - i) / (RATE * 1.2))
            * sum(math.sin(2 * math.pi * f * i / RATE) for f in (220.0, 277.18, 329.63)) for i in range(n)]


# name -> (function that returns the samples, what it is for)
CUES = {
    'hum': (_hum, '55 Hz hum (4 s): scene start'),
    'key': (lambda: _tone(1800, 0.03, 0.35, attack=0.001, decay=0.008), 'key tick: a request goes out'),
    'lock': (lambda: _tone(70, 0.22, 0.8, attack=0.002, decay=0.07, freq_end=45) + _silence(0.04)
             + _tone(440, 0.09, 0.4, decay=0.05) + _tone(330, 0.16, 0.4, decay=0.08),
             'low thunk plus two-tone lock: the engine BLOCKED a request'),
    'data': (lambda: _tone(1200, 0.05, 0.3, attack=0.002, decay=0.02), 'data tick: the engine ALLOWED a request'),
    'gap': (lambda: _silence(0.4), 'silence gap (0.4 s): scene change'),
    'ping': (lambda: _tone(660, 0.12, 0.4, decay=0.08) + _tone(990, 0.3, 0.4, decay=0.14),
             'rising two-note ping: a required result was observed'),
    'pad': (_pad, 'soft pad (3 s): the open challenge'),
}


def write_wav(path, samples):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


class Sound:
    """The cues of one take. enabled=False records nothing and plays nothing."""

    def __init__(self, enabled, folder, out=print, player=PLAYER, t0=None, lines=True):
        self.enabled, self.folder, self.out, self.lines = enabled, str(folder), out, lines
        self.player = player if player and os.path.isfile(player) and os.access(player, os.X_OK) else None
        self.t0 = t0 if t0 is not None else time.monotonic()
        self.used, self._files, self._procs = [], {}, []

    def cue(self, name):
        if not self.enabled:
            return
        t = round(time.monotonic() - self.t0, 3)
        if name not in self._files:
            path = os.path.join(self.folder, 'cue-%s.wav' % name)
            write_wav(path, CUES[name][0]())
            self._files[name] = path
        how = 'sheet only'
        if self.player and name != 'gap':  # a gap is silence: nothing to play
            self._procs.append(subprocess.Popen([self.player, self._files[name]], stdin=subprocess.DEVNULL,
                                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            how = 'played'
        elif not self.player and self.lines:
            how = 'printed'
            self.out('cue| t=%.3f %s' % (t, name))
        self.used.append({'t': t, 'cue': name, 'how': how})

    def sheet(self, path):
        """Write the cues that this run really used, with their measured offsets from the take start."""
        doc = {'unit': 'seconds from take start (measured, time.monotonic)', 'player': self.player or ('none (cue| lines)' if self.lines else 'none (sheet only)'),
               'cues': self.used, 'legend': {k: v[1] for k, v in CUES.items()}}
        with open(path, 'w') as f:
            json.dump(doc, f, indent=1)
            f.write('\n')

    def close(self):
        for p in self._procs:
            if p.poll() is None:
                try:
                    p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    p.kill()
