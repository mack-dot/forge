#!/usr/bin/env python3
"""Read the OS hardware inventory; emit no serial number, UUID, or device ID."""

import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

command = ['/usr/sbin/system_profiler', 'SPHardwareDataType', '-json', '-detailLevel', 'mini']
child = subprocess.run(command, capture_output=True, text=True)
fields = ('chip_type', 'cpu_type', 'machine_model', 'machine_name', 'physical_memory',
          'number_processors', 'current_processor_speed', 'packages', 'total_number_cores')
hardware = []
if child.returncode == 0:
    hardware = [{key: item[key] for key in fields if key in item}
                for item in json.loads(child.stdout).get('SPHardwareDataType', [])]
print(json.dumps({'command': command, 'exit_code': child.returncode,
                  'system_profiler_sha256': hashlib.sha256(Path(command[0]).read_bytes()).hexdigest(),
                  'hardware': hardware, 'stderr': child.stderr, 'logical_cpu_count': os.cpu_count(),
                  'platform': platform.platform(), 'redacted_fields': 'Serial numbers, UUIDs, and device identifiers omitted.'},
                 indent=2, sort_keys=True))
sys.exit(child.returncode if child.returncode else (0 if hardware else 1))
