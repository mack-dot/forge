#!/usr/bin/env python3
"""Observe real subprocess returns; execute the unchanged upstream CLI."""
import json
import os
import runpy
import subprocess
import sys
from pathlib import Path

output, *arguments = sys.argv[1:]
program = Path('/work/tools/oft/__main__.py')
run_code = subprocess.run.__code__
with open(output, 'x') as stream:
    def trace(frame, event, arg):
        if frame.f_code is run_code and event == 'return' and isinstance(arg, subprocess.CompletedProcess):
            stream.write(json.dumps({'command': arg.args, 'exit_code': arg.returncode}) + '\n')
            stream.flush()
        return trace

    # Match /work/oft's shell launcher: PYTHONPATH=/work/tools:$PYTHONPATH
    # python3 -m oft --root /work <arguments>. Only observation is added.
    sys.argv = [str(program), '--root', '/work', *arguments]
    sys.path.insert(0, '/work/tools')
    os.environ['PYTHONPATH'] = '/work/tools' + (':' + os.environ['PYTHONPATH'] if os.environ.get('PYTHONPATH') else '')
    sys.settrace(trace)
    try:
        runpy.run_module('oft', run_name='__main__', alter_sys=True)
    finally:
        sys.settrace(None)
