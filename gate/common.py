"""Shared record handling; no program semantics or proof decisions."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


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
