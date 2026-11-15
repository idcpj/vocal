"""
Harness to manage compilation, launch, and NDJSON event capture for VocalHostApp.
"""

import asyncio
import json
import os
import signal
import subprocess
import sys
from typing import Optional, Dict, Any, List, Callable, Tuple

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAC_SOURCE = os.path.join(PROJECT_ROOT, "mac", "VocalHostApp.swift")
BUILD_DIR = os.path.join(PROJECT_ROOT, "build_test")
HOST_BINARY = os.path.join(BUILD_DIR, "VocalHostTest")


def compile_mac_host() -> str:
    """Compiles mac/VocalHostApp.swift into build_test/VocalHostTest if needed."""
    os.makedirs(BUILD_DIR, exist_ok=True)
    
    # Check if compilation is needed based on mtime
    source_mtime = os.path.getmtime(MAC_SOURCE)
    if os.path.exists(HOST_BINARY):
        binary_mtime = os.path.getmtime(HOST_BINARY)
        if binary_mtime > source_mtime:
            return HOST_BINARY

    print("🔨 Compiling Mac Host for E2E tests: swiftc mac/VocalHostApp.swift...")
    cmd = [
        "swiftc",
        "-o", HOST_BINARY,
        MAC_SOURCE,
        "-parse-as-library"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"Swift compilation failed:\n{res.stderr}")
    print(f"✅ Mac Host compiled successfully -> {HOST_BINARY}")
    return HOST_BINARY


class HostProcessHarness:
    """Spawns VocalHostApp in --test-mode, reads NDJSON stdout events, provides assertion helpers."""

    def __init__(self, port: int = 18888, ping_interval: float = 1.0, mock_inject: bool = True,
                 require_pin: bool = False, pin_code: Optional[str] = None,
                 extra_args: Optional[List[str]] = None):
        self.port = port
        self.ping_interval = ping_interval
        self.mock_inject = mock_inject
        self.require_pin = require_pin
        self.pin_code = pin_code
        self.extra_args = extra_args or []
        self.proc: Optional[asyncio.subprocess.Process] = None
        self.events: List[Dict[str, Any]] = []
        self._event_waiters: List[Tuple[Callable[[Dict[str, Any]], bool], asyncio.Future]] = []
        self._reader_task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        """Launches the compiled MacHost process and starts background stdout event reader."""
        compile_mac_host()

        args = [
            HOST_BINARY,
            "--test-mode",
            f"--port={self.port}",
            f"--ping-interval={self.ping_interval}"
        ]
        if self.mock_inject:
            args.append("--no-cg-inject")
        if self.require_pin:
            args.append("--require-pin")
        if self.pin_code:
            args.append(f"--pin={self.pin_code}")
        if self.extra_args:
            args.extend(self.extra_args)

        self.proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        self._reader_task = asyncio.create_task(self._read_stdout())

        # Wait for SERVER_READY event
        ready_event = await self.wait_for_event("SERVER_READY", timeout=5.0)
        assert ready_event.get("port") == self.port, f"Expected port {self.port}, got {ready_event.get('port')}"

    async def _read_stdout(self) -> None:
        """Continuously reads lines from process stdout and parses JSON events."""
        if not self.proc or not self.proc.stdout:
            return

        while True:
            line_bytes = await self.proc.stdout.readline()
            if not line_bytes:
                break
            line = line_bytes.decode('utf-8', errors='replace').strip()
            if not line:
                continue

            # Look for NDJSON events
            if line.startswith("{") and "vocal_event" in line:
                try:
                    event = json.loads(line)
                    self.events.append(event)
                    self._dispatch_event(event)
                except Exception:
                    pass

    def _dispatch_event(self, event: Dict[str, Any]) -> None:
        """Resolves any pending event waiters."""
        remaining_waiters = []
        for predicate, future in self._event_waiters:
            if not future.done() and predicate(event):
                future.set_result(event)
            else:
                remaining_waiters.append((predicate, future))
        self._event_waiters = remaining_waiters

    async def wait_for_event(
        self,
        event_name: str,
        predicate: Optional[Callable[[Dict[str, Any]], bool]] = None,
        timeout: float = 5.0
    ) -> Dict[str, Any]:
        """Waits for a specific event matching event_name and optional predicate."""
        # First check existing events
        for ev in self.events:
            if ev.get("vocal_event") == event_name:
                if predicate is None or predicate(ev):
                    return ev

        # Otherwise wait for incoming event
        loop = asyncio.get_running_loop()
        future = loop.create_future()

        def match_fn(ev: Dict[str, Any]) -> bool:
            if ev.get("vocal_event") == event_name:
                return predicate(ev) if predicate else True
            return False

        self._event_waiters.append((match_fn, future))
        try:
            return await asyncio.wait_for(future, timeout=timeout)
        except asyncio.TimeoutError:
            matched_events = [e.get("vocal_event") for e in self.events]
            raise TimeoutError(
                f"Timed out waiting for event '{event_name}' after {timeout}s. Received so far: {matched_events}"
            )

    async def stop(self) -> None:
        """Gracefully terminates the MacHost process."""
        if self._reader_task:
            self._reader_task.cancel()
        if self.proc:
            try:
                self.proc.terminate()
                await asyncio.wait_for(self.proc.wait(), timeout=2.0)
            except Exception:
                try:
                    self.proc.kill()
                except Exception:
                    pass
            self.proc = None
