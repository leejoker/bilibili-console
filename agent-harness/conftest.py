"""Pytest configuration for the bilic harness.

Keeps every test off the real harness state directory and makes the source tree
importable before `pip install -e` has run.
"""

import os
import sys
from pathlib import Path

import pytest

HARNESS_ROOT = Path(__file__).resolve().parent
if str(HARNESS_ROOT) not in sys.path:
    sys.path.insert(0, str(HARNESS_ROOT))


@pytest.fixture(autouse=True)
def isolated_state_dir(tmp_path, monkeypatch):
    """Point the harness session/history state at a throwaway directory."""
    state_dir = tmp_path / "harness-state"
    monkeypatch.setenv("CLI_ANYTHING_BILIC_STATE_DIR", str(state_dir))
    return state_dir


@pytest.fixture
def state_dir(isolated_state_dir):
    return isolated_state_dir


@pytest.fixture
def bilic_path():
    """Real bilic executable; tests that need it fail loudly if it is missing."""
    from cli_anything.bilic.utils import bilic_backend

    try:
        return bilic_backend.find_bilic()
    except bilic_backend.BilicNotFoundError as exc:  # pragma: no cover - env dependent
        pytest.fail(f"bilic executable is required for this test: {exc}")
