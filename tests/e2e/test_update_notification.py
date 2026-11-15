"""
E2E Integration Tests for Multi-Channel Update Notification (GitHub & MAS).
Verifies UPDATE_CHECK_STARTED, UPDATE_CHECK_RESULT, UPDATE_CHECK_ERROR,
channel routing, semver comparison, asset parsing, and NDJSON event contract.
"""

import asyncio
import json
import os
import sys
from typing import Dict, Any, Tuple

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from tests.e2e.host_process import HostProcessHarness
from tests.e2e.virtual_client import VirtualMobileClient


class MockUpdateHttpServer:
    """Lightweight zero-dependency async HTTP server for mocking GitHub & MAS update endpoints."""

    def __init__(self, routes: Dict[str, Tuple[str, str, bytes]]):
        self.routes = routes
        self.server = None
        self.port = 0

    async def start(self) -> int:
        self.server = await asyncio.start_server(self._handle_client, "127.0.0.1", 0)
        self.port = self.server.sockets[0].getsockname()[1]
        return self.port

    async def _handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            req_line = await reader.readline()
            if not req_line:
                writer.close()
                return
            parts = req_line.decode("utf-8", errors="replace").split()
            path = parts[1] if len(parts) >= 2 else "/"

            while True:
                line = await reader.readline()
                if not line or line in (b"\r\n", b"\n"):
                    break

            if path in self.routes:
                status, ctype, body = self.routes[path]
                header = (
                    f"HTTP/1.1 {status}\r\n"
                    f"Content-Type: {ctype}\r\n"
                    f"Content-Length: {len(body)}\r\n"
                    f"Connection: close\r\n\r\n"
                )
                writer.write(header.encode("utf-8") + body)
            else:
                body = b"Not Found"
                header = (
                    "HTTP/1.1 404 Not Found\r\n"
                    f"Content-Length: {len(body)}\r\n"
                    "Connection: close\r\n\r\n"
                )
                writer.write(header.encode("utf-8") + body)
            await writer.drain()
        except Exception:
            pass
        finally:
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass

    async def stop(self) -> None:
        if self.server:
            self.server.close()
            await self.server.wait_closed()


async def test_github_update_available() -> None:
    """[TC-E2E-21] GitHub Release update check detects new version and DMG download URL."""
    print("  [TC-E2E-21] Testing GitHub Releases update detection (new version available)...")
    github_payload = json.dumps({
        "tag_name": "v1.2.0",
        "name": "Vocal v1.2.0",
        "body": "## What's New in 1.2.0\n- High speed voice input\n- Update notification",
        "html_url": "https://github.com/idcpj/vocal/releases/tag/v1.2.0",
        "assets": [
            {
                "name": "VocalHost-1.2.0.dmg",
                "browser_download_url": "https://github.com/idcpj/vocal/releases/download/v1.2.0/VocalHost-1.2.0.dmg"
            }
        ]
    }).encode("utf-8")

    server = MockUpdateHttpServer({
        "/github/latest": ("200 OK", "application/json", github_payload)
    })
    server_port = await server.start()
    update_url = f"http://127.0.0.1:{server_port}/github/latest"

    host_port = 19401
    host = HostProcessHarness(
        port=host_port,
        mock_inject=True,
        extra_args=[
            "--update-channel=github",
            f"--update-url={update_url}",
            "--check-update-on-launch"
        ]
    )

    try:
        await host.start()

        # 1. Assert UPDATE_CHECK_STARTED
        started_event = await host.wait_for_event(
            "UPDATE_CHECK_STARTED",
            predicate=lambda e: e.get("channel") == "github",
            timeout=5.0
        )
        assert started_event["channel"] == "github"
        assert started_event["url"] == update_url
        print(f"    ✅ UPDATE_CHECK_STARTED emitted: {started_event.get('url')}")

        # 2. Assert UPDATE_CHECK_RESULT
        result_event = await host.wait_for_event(
            "UPDATE_CHECK_RESULT",
            predicate=lambda e: e.get("channel") == "github",
            timeout=5.0
        )
        assert result_event["hasUpdate"] is True, f"Expected hasUpdate=True, got {result_event.get('hasUpdate')}"
        assert result_event["latestVersion"] == "1.2.0", f"Expected latestVersion=1.2.0, got {result_event.get('latestVersion')}"
        assert "VocalHost-1.2.0.dmg" in result_event.get("downloadUrl", ""), f"DMG download URL mismatch: {result_event.get('downloadUrl')}"
        assert result_event["isIgnored"] is False
        print(f"    ✅ UPDATE_CHECK_RESULT verified: latestVersion=1.2.0, hasUpdate=True, dmgUrl={result_event.get('downloadUrl')}")

    finally:
        await host.stop()
        await server.stop()


async def test_github_up_to_date() -> None:
    """[TC-E2E-22] GitHub Release update check when host is already at or above latest version."""
    print("  [TC-E2E-22] Testing GitHub Releases update check (already up-to-date)...")
    github_payload = json.dumps({
        "tag_name": "v1.0.0",
        "name": "Vocal v1.0.0",
        "body": "Initial release",
        "html_url": "https://github.com/idcpj/vocal/releases/tag/v1.0.0",
        "assets": []
    }).encode("utf-8")

    server = MockUpdateHttpServer({
        "/github/latest": ("200 OK", "application/json", github_payload)
    })
    server_port = await server.start()
    update_url = f"http://127.0.0.1:{server_port}/github/latest"

    host_port = 19402
    host = HostProcessHarness(
        port=host_port,
        mock_inject=True,
        extra_args=[
            "--update-channel=github",
            f"--update-url={update_url}",
            "--check-update-on-launch"
        ]
    )

    try:
        await host.start()

        result_event = await host.wait_for_event(
            "UPDATE_CHECK_RESULT",
            predicate=lambda e: e.get("channel") == "github",
            timeout=5.0
        )
        assert result_event["hasUpdate"] is False, f"Expected hasUpdate=False, got {result_event.get('hasUpdate')}"
        assert result_event["latestVersion"] == "1.0.0"
        print(f"    ✅ Already up-to-date verified: hasUpdate=False, currentVersion={result_event.get('currentVersion')}")

    finally:
        await host.stop()
        await server.stop()


async def test_mas_update_available() -> None:
    """[TC-E2E-23] Mac App Store (MAS) iTunes lookup update check detects new store version."""
    print("  [TC-E2E-23] Testing Mac App Store (MAS) update check...")
    mas_payload = json.dumps({
        "resultCount": 1,
        "results": [
            {
                "version": "2.1.0",
                "releaseNotes": "MAS Update: New speech models and UI improvements",
                "trackViewUrl": "https://apps.apple.com/app/vocal/id987654321?mt=12"
            }
        ]
    }).encode("utf-8")

    server = MockUpdateHttpServer({
        "/mas/lookup": ("200 OK", "application/json", mas_payload)
    })
    server_port = await server.start()
    update_url = f"http://127.0.0.1:{server_port}/mas/lookup"

    host_port = 19403
    host = HostProcessHarness(
        port=host_port,
        mock_inject=True,
        extra_args=[
            "--update-channel=mas",
            f"--update-url={update_url}",
            "--check-update-on-launch"
        ]
    )

    try:
        await host.start()

        started_event = await host.wait_for_event(
            "UPDATE_CHECK_STARTED",
            predicate=lambda e: e.get("channel") == "mas",
            timeout=5.0
        )
        assert started_event["channel"] == "mas"
        print(f"    ✅ MAS check started: {started_event.get('url')}")

        result_event = await host.wait_for_event(
            "UPDATE_CHECK_RESULT",
            predicate=lambda e: e.get("channel") == "mas",
            timeout=5.0
        )
        assert result_event["hasUpdate"] is True
        assert result_event["latestVersion"] == "2.1.0"
        assert "apps.apple.com" in result_event.get("downloadUrl", "")
        print(f"    ✅ MAS update verified: latestVersion=2.1.0, storeUrl={result_event.get('downloadUrl')}")

    finally:
        await host.stop()
        await server.stop()


async def test_update_error_resilience() -> None:
    """[TC-E2E-24] Update check gracefully handles HTTP 500 error without crash or hang."""
    print("  [TC-E2E-24] Testing update check network/server error resilience...")
    server = MockUpdateHttpServer({
        "/error_endpoint": ("500 Internal Server Error", "text/plain", b"Internal Server Error")
    })
    server_port = await server.start()
    update_url = f"http://127.0.0.1:{server_port}/error_endpoint"

    host_port = 19404
    host = HostProcessHarness(
        port=host_port,
        mock_inject=True,
        extra_args=[
            "--update-channel=github",
            f"--update-url={update_url}",
            "--check-update-on-launch"
        ]
    )

    try:
        await host.start()

        error_event = await host.wait_for_event(
            "UPDATE_CHECK_ERROR",
            predicate=lambda e: e.get("channel") == "github",
            timeout=5.0
        )
        assert error_event["channel"] == "github"
        assert "500" in error_event.get("error", "")
        print(f"    ✅ UPDATE_CHECK_ERROR properly captured: {error_event.get('error')}")

    finally:
        await host.stop()
        await server.stop()


async def test_update_preferences_and_actions() -> None:
    """[TC-E2E-25] Tests toggling auto check, ignoring specific version, and resetting ignored version."""
    print("  [TC-E2E-25] Testing update preferences and actions (toggle auto-check, ignore, reset)...")
    host_port = 19405
    host = HostProcessHarness(
        port=host_port,
        mock_inject=True
    )
    client = VirtualMobileClient(port=host_port)

    try:
        await host.start()
        await client.connect()

        # 1. Toggle auto-check (default is True -> False)
        await client.send_text(json.dumps({"type": "update_control", "action": "toggle_auto_check"}))
        event_toggle1 = await host.wait_for_event(
            "UPDATE_AUTO_CHECK_TOGGLED",
            predicate=lambda e: e.get("enabled") is False,
            timeout=5.0
        )
        assert event_toggle1.get("enabled") is False
        print(f"    ✅ Auto check toggled to False: {event_toggle1}")

        # 2. Ignore specific version "1.3.0"
        await client.send_text(json.dumps({"type": "update_control", "action": "ignore_version", "version": "1.3.0"}))
        event_ignore = await host.wait_for_event(
            "UPDATE_ACTION_IGNORED",
            predicate=lambda e: e.get("version") == "1.3.0",
            timeout=5.0
        )
        assert event_ignore.get("version") == "1.3.0"
        print(f"    ✅ Version ignored: {event_ignore}")

        # 3. Reset ignored version
        await client.send_text(json.dumps({"type": "update_control", "action": "reset_ignored"}))
        event_reset = await host.wait_for_event(
            "UPDATE_ACTION_RESET_IGNORED",
            predicate=lambda e: e.get("previousVersion") == "1.3.0",
            timeout=5.0
        )
        assert event_reset.get("previousVersion") == "1.3.0"
        print(f"    ✅ Ignored version reset: {event_reset}")

        # 4. Toggle auto-check back to True
        await client.send_text(json.dumps({"type": "update_control", "action": "toggle_auto_check"}))
        event_toggle2 = await host.wait_for_event(
            "UPDATE_AUTO_CHECK_TOGGLED",
            predicate=lambda e: e.get("enabled") is True,
            timeout=5.0
        )
        assert event_toggle2.get("enabled") is True
        print(f"    ✅ Auto check toggled back to True: {event_toggle2}")

    finally:
        await client.close()
        await host.stop()


async def run_all_update_tests() -> bool:
    """Runs all update notification E2E test cases."""
    print("\n-------------------------------------------------------------")
    print("📦 [E2E Suite] 多渠道版本更新提示机制测试 (GitHub & MAS Update)")
    print("-------------------------------------------------------------")
    try:
        await test_github_update_available()
        await test_github_up_to_date()
        await test_mas_update_available()
        await test_update_error_resilience()
        await test_update_preferences_and_actions()
        print("  ✅ 多渠道版本更新提示测试套件全部通过！")
        return True
    except Exception as e:
        print(f"  ❌ 多渠道版本更新提示测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    asyncio.run(run_all_update_tests())
