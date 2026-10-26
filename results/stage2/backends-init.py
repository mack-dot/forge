"""Explicit backend registry. Only the current Dafny adapter is implemented."""

from . import dafny

DEFAULT_BACKEND = 'dafny'
BACKENDS = {'dafny': dafny}


def get_backend(name):
    return BACKENDS[name]
