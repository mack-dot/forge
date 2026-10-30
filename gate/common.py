"""Shared record handling; no program semantics or proof decisions."""

import hashlib
import json
from pathlib import Path
import platform

ROOT = Path(__file__).resolve().parent.parent

# Toolchain pin files per host profile. 'local' is the recorded macOS arm64 host;
# 'linux' is the pinned ubuntu-22.04 x86_64 CI profile. Any other host has no pinned
# toolchain and every gate refuses (TOOLCHAIN_ERROR, exit 2).
PIN_FILES = {
    'local': {'dafny': 'toolchain/pins.json', 'validator': 'toolchain/validator-pins.json',
              'javascript': 'toolchain/javascript-pins.json'},
    'linux': {'dafny': 'toolchain/linux-pins.json', 'validator': 'toolchain/validator-linux-pins.json',
              'javascript': 'toolchain/javascript-linux-pins.json'},
}
HOST_PROFILES = {('Darwin', 'arm64'): 'local', ('Linux', 'x86_64'): 'linux'}


def host_profile():
    key = (platform.system(), platform.machine())
    if key not in HOST_PROFILES:
        raise RuntimeError('TOOLCHAIN_ERROR: no pinned toolchain profile for ' + '/'.join(key))
    return HOST_PROFILES[key]


def pin_file(kind, profile=None):
    return PIN_FILES[profile or host_profile()][kind]


class Rejected(Exception):
    pass


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'),
                       ensure_ascii=True, allow_nan=False) + '\n').encode('utf-8')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def relative(path):
    return path.resolve().relative_to(ROOT).as_posix()


def read_json(path):
    def unique_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise Rejected('DOCUMENT_FORMAT: duplicate JSON key ' + key)
            result[key] = value
        return result

    def invalid_number(value):
        raise Rejected('DOCUMENT_FORMAT: non-JSON number ' + value)

    return json.loads(path.read_text(), object_pairs_hook=unique_keys,
                      parse_constant=invalid_number)
