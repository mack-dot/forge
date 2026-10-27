#!/usr/bin/env python3
"""Observe real subprocess returns; execute the unchanged upstream CLI."""
import json
import runpy
import subprocess
import sys
from pathlib import Path

output, *arguments = sys.argv[1:]
program = Path('/work/oft')
run_code = subprocess.run.__code__
with open(output, 'x') as stream:
    def trace(frame, event, arg):
        if frame.f_code is run_code and event == 'return' and isinstance(arg, subprocess.CompletedProcess):
            stream.write(json.dumps({'command': arg.args, 'exit_code': arg.returncode}) + '\n')
            stream.flush()
        return trace

    sys.argv = [str(program), *arguments]
    sys.path.insert(0, str(program.parent))
    sys.settrace(trace)
    try:
        runpy.run_path(str(program), run_name='__main__')
    finally:
        sys.settrace(None)
