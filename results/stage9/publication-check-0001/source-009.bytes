"""Explicit lazy backend registry; evidence never selects executable paths."""

from importlib import import_module

DEFAULT_BACKEND = 'dafny'
BACKENDS = {'dafny': 'backends.dafny', 'typescript': 'backends.typescript'}


def get_backend(name):
    return import_module(BACKENDS[name])
