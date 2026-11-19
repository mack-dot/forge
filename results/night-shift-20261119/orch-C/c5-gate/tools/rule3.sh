#!/bin/bash
# Runs orch-B's rule 3 recognizer (read-only, by path) on the given files. Prints one line per file.
exec /usr/local/bin/python3.10 -I <REPO>/results/night-shift-20261119/orch-B/e-subset3/subset_rule3.py "$@"
