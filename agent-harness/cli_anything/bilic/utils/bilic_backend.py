"""bilic backend - subprocess wrapper around the real bilic executable.

Every bilibili interaction goes through the real `bilic` command
(bilibili-console, a Thor CLI). This module never performs HTTP itself: it
locates the executable, runs it without a shell, and returns a structured
result. Reimplementing the bilibili API calls in Python is explicitly out of
scope (HARNESS.md "Use the Real Software").
"""

import os
import shutil
import subprocess
import time

BILIC_BIN_ENV = "BILIC_BIN"
DEFAULT_TIMEOUT = 120

INSTALL_HINT = (
    "bilic (bilibili-console) was not found.\n"
    "Install the Ruby gem that provides it:\n"
    "  gem install bilibili_console\n"
    "or point BILIC_BIN at the executable, for example:\n"
    "  export BILIC_BIN=$(which bilic)"
)

# bilic reports failures as "Error! <Class>: <message>" on stdout; current
# builds exit non-zero, but older builds logged the error and still exited 0,
# so classify_failure never trusts the exit code alone.
_RUNTIME_ERROR_PREFIX = "Error!"


class BilicNotFoundError(RuntimeError):
    """Raised when the real bilic executable cannot be located."""


def find_bilic(env=None):
    """Locate the bilic executable.

    Order: $BILIC_BIN override, then PATH lookup.

    Raises:
        BilicNotFoundError: when no usable executable is found.
    """
    env = os.environ if env is None else env
    override = str(env.get(BILIC_BIN_ENV) or "").strip()
    if override:
        if os.path.isfile(override) and os.access(override, os.X_OK):
            return override
        raise BilicNotFoundError(
            f"{BILIC_BIN_ENV}={override} is not an executable file.\n{INSTALL_HINT}"
        )

    found = shutil.which("bilic")
    if found:
        return found
    raise BilicNotFoundError(INSTALL_HINT)


def _runtime_error_line(stdout):
    for line in stdout.splitlines():
        stripped = line.strip()
        if stripped.startswith(_RUNTIME_ERROR_PREFIX):
            return stripped
    return None


def classify_failure(stdout, stderr, exit_code):
    """Map an invocation outcome onto (error_kind, message), or (None, None).

    The exit code alone is not trustworthy: bilic swallows exceptions in its
    at_exit hook and still exits 0, and bilibili's WAF answers with an HTML
    page that makes the Ruby JSON parser explode.
    """
    combined = f"{stdout}\n{stderr}"
    error_line = _runtime_error_line(stdout)

    if "<!DOCTYPE" in combined or "JSON::ParserError" in combined:
        detail = f" ({error_line})" if error_line else ""
        return (
            "upstream_response_error",
            "bilic received a non-JSON response instead of an API payload "
            "(bilibili risk control / WAF, or the proxy is not forwarding)."
            + detail,
        )
    if error_line:
        return ("bilic_error", error_line)
    if exit_code != 0:
        tail = [line for line in (stderr.strip() or stdout.strip()).splitlines() if line.strip()]
        last = tail[-1] if tail else "no output"
        return ("nonzero_exit", f"bilic exited with status {exit_code}: {last}")
    return (None, None)


def run_bilic(args, timeout=DEFAULT_TIMEOUT, env=None, stdin=None):
    """Run the real bilic executable and return a structured result.

    Args:
        args: Arguments after the executable name, e.g. ("tree",).
        timeout: Seconds before the child is killed and reported as a timeout.
        env: Optional environment mapping (defaults to this process env).
        stdin: Optional stdin handle; defaults to an empty device so commands
            such as `login` cannot silently consume harness input.

    Returns:
        dict with binary, argv, exit_code, stdout, stderr, ok, error_kind,
        error, duration_ms.
    """
    binary = find_bilic(env)
    argv = [binary, *[str(arg) for arg in args]]
    run_env = dict(os.environ if env is None else env)
    started = time.perf_counter()

    try:
        proc = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            timeout=timeout,
            stdin=subprocess.DEVNULL if stdin is None else stdin,
            env=run_env,
            shell=False,
        )
    except subprocess.TimeoutExpired:
        return {
            "binary": binary,
            "argv": argv,
            "exit_code": None,
            "stdout": "",
            "stderr": "",
            "ok": False,
            "error_kind": "timeout",
            "error": f"bilic timed out after {timeout}s: {' '.join(argv)}",
            "duration_ms": int((time.perf_counter() - started) * 1000),
        }
    except OSError as exc:
        return {
            "binary": binary,
            "argv": argv,
            "exit_code": None,
            "stdout": "",
            "stderr": "",
            "ok": False,
            "error_kind": "binary_not_found",
            "error": f"could not execute {binary}: {exc}\n{INSTALL_HINT}",
            "duration_ms": int((time.perf_counter() - started) * 1000),
        }

    stdout = proc.stdout or ""
    stderr = proc.stderr or ""
    error_kind, error = classify_failure(stdout, stderr, proc.returncode)
    return {
        "binary": binary,
        "argv": argv,
        "exit_code": proc.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "ok": error_kind is None,
        "error_kind": error_kind,
        "error": error,
        "duration_ms": int((time.perf_counter() - started) * 1000),
    }