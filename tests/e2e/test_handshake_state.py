"""
E2E Test: Handshake, mDNS Discovery, and State Synchronization.
Corresponds to TC-E2E-01 and TC-E2E-02 in e2e-testing-architecture.md.
"""

import asyncio
from typing import Dict, Any

from tests.e2e.host_process import HostProcessHarness
from tests.e2e.virtual_client import VirtualMobileClient, check_mdns_discovery


async def test_mdns_publication_and_discovery(port: int = 19101) -> None:
    """TC-E2E-01: Verifies Bonjour / mDNS service publication and event contract."""
    print("  [TC-E2E-01] Testing mDNS publication and discovery...")
    harness = HostProcessHarness(port=port)
    try:
        await harness.start()

        # 1. Assert MDNS_PUBLISHED event was emitted by MacHost
        mdns_event = await harness.wait_for_event(
            "MDNS_PUBLISHED",
            predicate=lambda e: e.get("port") == port and e.get("type") == "_vocal._tcp",
            timeout=5.0
        )
        assert mdns_event is not None, "MacHost did not emit MDNS_PUBLISHED event"
        assert mdns_event["type"] == "_vocal._tcp", f"Invalid service type: {mdns_event['type']}"
        assert mdns_event["port"] == port, f"Port mismatch: expected {port}, got {mdns_event['port']}"
        print(f"    ✅ MacHost published mDNS service: {mdns_event.get('serviceName')}")

        # 2. Local system Bonjour query via dns-sd
        found, msg = check_mdns_discovery(port, timeout_sec=2.0)
        # Note: In restricted sandboxes dns-sd might need extra privileges, so warn if not found
        if found:
            print(f"    ✅ System Bonjour resolver verified: {msg}")
        else:
            print(f"    ℹ️  dns-sd notice (common in CI/sandboxes): {msg}")

    finally:
        await harness.stop()


async def test_websocket_handshake_and_state_sync(port: int = 19102) -> None:
    """TC-E2E-02: Verifies WebSocket handshake and two-way state machine synchronization."""
    print("  [TC-E2E-02] Testing WebSocket handshake and state synchronization...")
    harness = HostProcessHarness(port=port)
    client = VirtualMobileClient(host="127.0.0.1", port=port)

    try:
        await harness.start()

        # Connect client to MacHost
        await client.connect(timeout=5.0)
        assert client.is_connected, "Virtual client failed to connect"

        # Assert MacHost transitioned state to CONNECTED
        state_connected = await harness.wait_for_event(
            "STATE_CHANGE",
            predicate=lambda e: e.get("to") == "CONNECTED",
            timeout=5.0
        )
        assert state_connected["to"] == "CONNECTED", "Host did not transition to CONNECTED"
        print("    ✅ MacHost transitioned state to CONNECTED upon handshake")

        # Disconnect client cleanly
        await client.close(code=1000)
        assert not client.is_connected, "Client should be disconnected after close"

        # Assert MacHost transitioned state to DISCONNECTED
        state_disconnected = await harness.wait_for_event(
            "STATE_CHANGE",
            predicate=lambda e: e.get("to") == "DISCONNECTED",
            timeout=5.0
        )
        assert state_disconnected["to"] == "DISCONNECTED", "Host did not transition to DISCONNECTED"
        print("    ✅ MacHost transitioned state to DISCONNECTED upon client close")

    finally:
        if client.is_connected:
            await client.close()
        await harness.stop()


async def run_handshake_state_tests(base_port: int = 19100) -> bool:
    """Executes all handshake and state synchronization tests."""
    print("\n▶ Running Handshake & State Synchronization Tests...")
    try:
        await test_mdns_publication_and_discovery(port=base_port + 1)
        await test_websocket_handshake_and_state_sync(port=base_port + 2)
        print("✅ Handshake & State Synchronization Tests PASSED\n")
        return True
    except Exception as e:
        print(f"❌ Handshake & State Synchronization Tests FAILED: {e}\n")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    asyncio.run(run_handshake_state_tests())

