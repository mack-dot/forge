"""Negative control for run_exit_status_controls.py: replace the caller's decision by one that authorizes on
exit status 0 alone, then run the same rows. This script must EXIT 1 (rows differ). It restores the results file."""
import runpy
import shutil
import sys

import m1_fail_closed as fc

shutil.copy('exit_status_controls_results.json', 'exit_status_controls_results.keep')
fc.decide_from_result = lambda f, r: (('AUTHORIZED', 0, b'') if r.exit_code == 0 else ('REFUSED', 'D3 x'))
try:
    runpy.run_path('run_exit_status_controls.py', run_name='__main__')
finally:
    shutil.copy('exit_status_controls_results.json', 'exit_status_controls_broken_caller.json')
    shutil.move('exit_status_controls_results.keep', 'exit_status_controls_results.json')
