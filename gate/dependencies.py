"""Check the installed validator packages against observed content pins."""

import importlib.metadata
import platform
from pathlib import Path

from common import ROOT, digest, read_json


def check_dependencies():
    pins = read_json(ROOT / 'toolchain/validator-pins.json')
    if platform.python_version() != pins['python_version']:
        raise RuntimeError('TOOLCHAIN_ERROR: Python version differs from validator pin')
    for name, expected in pins['packages'].items():
        distribution = importlib.metadata.distribution(name)
        if distribution.version != expected['version']:
            raise RuntimeError('TOOLCHAIN_ERROR: ' + name + ' version differs from pin')
        for filename, checksum in expected['files'].items():
            if '..' in Path(filename).parts or Path(filename).is_absolute():
                raise RuntimeError('TOOLCHAIN_ERROR: invalid package pin path')
            if digest(distribution.locate_file(filename).read_bytes()) != checksum:
                raise RuntimeError('TOOLCHAIN_ERROR: ' + name + '/' + filename + ' digest differs')
    return {name: item['version'] for name, item in pins['packages'].items()}
