#!/usr/bin/env python3
# Review 3 test bytes: record the names of the environment variables, then never answer.
import json, os, time
with open('review3-env-names.json', 'w') as stream:
    json.dump({'names': sorted(os.environ), 'PYTHONNOUSERSITE': os.environ.get('PYTHONNOUSERSITE')}, stream)
time.sleep(120)
