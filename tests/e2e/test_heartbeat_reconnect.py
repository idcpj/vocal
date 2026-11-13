"""
E2E Test: Heartbeat ping/pong, network fault injection, and automatic reconnect self-healing.
Corresponds to TC-E2E-03, TC-E2E-07, and TC-E2E-08 in e2e-testing-architecture.md.
"""

import asyncio
import socket
import struct
from typing import Dict, Any

from tests.e2e.host_process import HostProcessHarness
from tests.e2e.virtual_client import VirtualMobileClient


async def test_bidirectional_heartbeat(port: int = 19301) -> None:
    """TC-E2E-03: Verifies 1.0s periodic Ping sent by MacHost and Pong acknowledged by client."""
    print("  [TC-E2E-03] Testing bi-directional heartbeat (Ping-Pong)...")
    # Set ping interval to 1.0s for rapid test execution
    harness = HostProcessHarness(port=port, ping_interval=1.0)
    client = VirtualMobileClient(host="127.0.0.1", port=port)

    try:
        await harness.start()
        await client.connect(timeout=5.0)

        # Wait for MacHost to emit PING_SENT
        ping_ev = await harness.wait_for_event("PING_SENT", timeout=3.0)
        assert ping_ev is not None, "MacHost did not emit PING_SENT"
        print("    ✅ Received PING_SENT from MacHost")

        # Client responds with Pong
        await client.send_pong()

        # Wait for MacHost to register PONG_RECEIVED
        pong_ev = await harness.wait_for_event("PONG_RECEIVED", timeout=3.0)
        assert pong_ev is not None, "MacHost did not emit PONG_RECEIVED"
        print("    ✅ PONG_RECEIVED registered by MacHost; connection alive and healthy")

    finally:
        if client.is_connected:
            await client.close()
        await harness.stop()


async def test_network_fault_and_reconnection_healing(port: int = 19302) -> None:
    """TC-E2E-08: Simulates network drop (TCP RST) and verifies self-healing auto-reconnect."""
    print("  [TC-E2E-08] Testing abrupt network drop and state self-healing reconnect...")
    harness = HostProcessHarness(port=port, ping_interval=1.0)
    client1 = VirtualMobileClient(host="127.0.0.1", port=port)

    try:
        await harness.start()
        # 1. Establish initial connection
        await client1.connect(timeout=5.0)
        await harness.wait_for_event(
            "STATE_CHANGE",
            predicate=lambda e: e.get("to") == "CONNECTED",
            timeout=5.0
        )
        print("    ✅ Initial connection established: CONNECTED")

        # 2. Simulate abrupt network drop (Wi-Fi off / TCP RST)
        client1.abort()
        print("    💥 Simulated abrupt network drop (TCP socket aborted)")

        # 3. Assert MacHost transitions back to DISCONNECTED
        disconnect_ev = await harness.wait_for_event(
            "STATE_CHANGE",
            predicate=lambda e: e.get("to") == "DISCONNECTED",
            timeout=5.0
        )
        assert disconnect_ev["to"] == "DISCONNECTED", "MacHost failed to transition to DISCONNECTED after drop"
        print("    ✅ MacHost state accurately transitioned to DISCONNECTED")

        # 4. Simulate mobile client re-discovering and auto-reconnecting
        await asyncio.sleep(0.5)
        client2 = VirtualMobileClient(host="127.0.0.1", port=port)
        await client2.connect(timeout=5.0)

        # 5. Assert MacHost transitions back to CONNECTED
        reconnected_ev = await harness.wait_for_event(
            "STATE_CHANGE",
            predicate=lambda e: e.get("to") == "CONNECTED",
            timeout=5.0
        )
        assert reconnected_ev["to"] == "CONNECTED", "MacHost failed to re-connect"
        print("    ✅ State machine self-healed: successfully reconnected")

        # 6. Verify text injection still functions normally after reconnect
        reconnect_msg = "重连恢复后的首条测试指令"
        await client2.send_json_draft(reconnect_msg, press_enter=False)
        inject_ev = await harness.wait_for_event(
            "TEXT_INJECTED",
            predicate=lambda e: e.get("text") == reconnect_msg,
            timeout=5.0
        )
        assert inject_ev["text"] == reconnect_msg, "Message failed after reconnection"
        print(f"    ✅ Injected successfully after reconnection: '{reconnect_msg}'")

        await client2.close()

    finally:
        await harness.stop()


async def test_concurrent_connection_resilience(port: int = 19303) -> None:
    """TC-E2E-10: Verifies that a secondary failed/aborted connection attempt (TCP probe/drop) does not disrupt an existing active connection."""
    print("  [TC-E2E-10] Testing concurrent connection resilience (secondary connection failure isolation)...")
    harness = HostProcessHarness(port=port, ping_interval=1.0)
    primary_client = VirtualMobileClient(host="127.0.0.1", port=port)

    try:
        await harness.start()

        # 1. Primary client establishes connection
        await primary_client.connect(timeout=5.0)
        await harness.wait_for_event(
            "STATE_CHANGE",
            predicate=lambda e: e.get("to") == "CONNECTED",
            timeout=5.0
        )
        print("    ✅ Primary client connected: CONNECTED")

        # 2. Secondary probe connects via raw TCP and immediately aborts (simulates duplicate socket drop/refusal)
        probe_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        probe_sock.connect(("127.0.0.1", port))
        # Force TCP RST on secondary socket
        probe_sock.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
        probe_sock.close()
        print("    ⚡ Secondary TCP probe connection aborted with RST")

        # 3. Assert MacHost stays in CONNECTED state (no false DISCONNECTED transition)
        await asyncio.sleep(1.0)
        recent_events = [e for e in harness.events if e.get("vocal_event") == "STATE_CHANGE"]
        assert recent_events[-1].get("to") == "CONNECTED", f"MacHost incorrectly disconnected due to secondary failure! Last event: {recent_events[-1]}"
        print("    ✅ MacHost remained CONNECTED; secondary failure safely isolated")

        # 4. Assert primary client can still send messages normally
        test_msg = "主连接持续正常工作"
        await primary_client.send_json_draft(test_msg, press_enter=False)
        inject_ev = await harness.wait_for_event(
            "TEXT_INJECTED",
            predicate=lambda e: e.get("text") == test_msg,
            timeout=5.0
        )
        assert inject_ev["text"] == test_msg
        print(f"    ✅ Primary client successfully injected text: '{test_msg}'")

        await primary_client.close()

    finally:
        await harness.stop()


async def run_heartbeat_reconnect_tests(base_port: int = 19300) -> bool:
    """Executes all heartbeat, fault tolerance, and reconnection tests."""
    print("\n▶ Running Heartbeat & Reconnection Self-Healing Tests...")
    try:
        await test_bidirectional_heartbeat(port=base_port + 1)
        await test_network_fault_and_reconnection_healing(port=base_port + 2)
        await test_concurrent_connection_resilience(port=base_port + 3)
        print("✅ Heartbeat & Reconnection Self-Healing Tests PASSED\n")
        return True
    except Exception as e:
        print(f"❌ Heartbeat & Reconnection Self-Healing Tests FAILED: {e}\n")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    asyncio.run(run_heartbeat_reconnect_tests())

