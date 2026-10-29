import json, sys
sys.path.insert(0, sys.argv[1] + "/gate/provenance")
from pathlib import Path
from common import Records, Rejected, context, source_tree
_, _, impl = context(sys.argv[2])
try:
    source_tree(Path(sys.argv[1]) / ".git", sys.argv[3], impl, Records(Path(sys.argv[4])))
    print("ACCEPTED")
except Rejected as error:
    print(error.reason); raise SystemExit(1)
