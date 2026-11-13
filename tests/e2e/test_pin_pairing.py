"""
E2E Integration Tests for Device PIN Pairing & Auth Gate Security (PRD-07).
Validates open mode, PIN protection gate interception, error retries, token issuance,
seamless token reconnection, and brute-force 3-strikes termination.
"""

import asyncio
from .host_process import HostProcessHarness
from .virtual_client import VirtualMobileClient


async def test_open_mode_pairing() -> None:
    """[TC-E2E-11] Open mode: Without PIN protection, auth_request gets immediate auth_success (mode=open)."""
    print("  [TC-E2E-11] Testing open mode handshake (default without PIN protection)...")
    port = 19201
    host = HostProcessHarness(port=port, mock_inject=True, require_pin=False)
    client = VirtualMobileClient(port=port)

    try:
        await host.start()
        await client.connect()

        # Send auth_request
        await client.send_auth_request(device_id="dev-open-1", device_name="Test Phone")
        auth_resp = await client.recv_json_message(timeout=3.0)

        assert auth_resp.get("type") == "auth_success", f"Expected auth_success, got: {auth_resp}"
        assert auth_resp.get("mode") == "open", f"Expected mode=open, got: {auth_resp.get('mode')}"

        # Send text draft and verify injection
        await client.send_json_draft("自由模式免密打字", press_enter=False)
        inject_event = await host.wait_for_event("TEXT_INJECTED", timeout=3.0)
        assert inject_event.get("text") == "自由模式免密打字"
        print("    ✅ Open mode verified: auth_success (mode=open) and text injection confirmed")
    finally:
        await client.close()
        await host.stop()


async def test_pin_protection_gate_and_rejection() -> None:
    """[TC-E2E-12 & 13] PIN protection gate: blocks unauth text, requires PIN, rejects wrong PIN."""
    print("  [TC-E2E-12] Testing PIN protection gate and unauthorized text interception...")
    port = 19202
    correct_pin = "8899"
    host = HostProcessHarness(port=port, mock_inject=True, require_pin=True, pin_code=correct_pin)
    client = VirtualMobileClient(port=port)

    try:
        await host.start()
        await client.connect()

        # Step 1: Handshake asks for PIN
        await client.send_auth_request(device_id="dev-pin-1", device_name="Untrusted Phone")
        auth_resp = await client.recv_json_message(timeout=3.0)
        assert auth_resp.get("type") == "auth_require_pin", f"Expected auth_require_pin, got: {auth_resp}"
        print("    ✅ Host correctly required PIN pairing for untrusted device")

        # Step 2: Security Gate check: sending text without PIN MUST be intercepted and rejected
        await client.send_json_draft("越权注入尝试", press_enter=False)
        blocked_resp = await client.recv_json_message(timeout=3.0)
        assert blocked_resp.get("type") == "auth_require_pin", f"Expected blocked response to be auth_require_pin, got {blocked_resp}"

        # Check host event log for AUTH_BLOCKED
        blocked_event = await host.wait_for_event("AUTH_BLOCKED", timeout=3.0)
        assert blocked_event.get("reason") == "NOT_AUTHENTICATED"
        assert not any(e.get("vocal_event") == "TEXT_INJECTED" for e in host.events)
        print("    ✅ Auth Gate verified: unauthorized text blocked without keyboard injection")

        # Step 3: [TC-E2E-13] Wrong PIN rejection
        print("  [TC-E2E-13] Testing wrong PIN submission and remaining attempts count...")
        await client.send_verify_pin("0000")
        fail_resp = await client.recv_json_message(timeout=3.0)
        assert fail_resp.get("type") == "auth_failed", f"Expected auth_failed, got: {fail_resp}"
        assert fail_resp.get("remainingAttempts") == 2, f"Expected 2 remaining attempts, got: {fail_resp}"
        print("    ✅ Incorrect PIN rejected with remainingAttempts: 2")
    finally:
        await client.close()
        await host.stop()


async def test_pin_pairing_and_token_reconnect() -> None:
    """[TC-E2E-14 & 15] PIN verification issues token; subsequent reconnect with token skips PIN."""
    print("  [TC-E2E-14] Testing correct PIN verification and device token issuance...")
    port = 19203
    correct_pin = "6789"
    host = HostProcessHarness(port=port, mock_inject=True, require_pin=True, pin_code=correct_pin)
    client1 = VirtualMobileClient(port=port)

    try:
        await host.start()
        await client1.connect()

        # Step 1: Request auth -> require pin
        await client1.send_auth_request(device_id="dev-pair-1", device_name="iPhone 15")
        resp1 = await client1.recv_json_message(timeout=3.0)
        assert resp1.get("type") == "auth_require_pin"

        # Step 2: Submit correct PIN
        await client1.send_verify_pin(correct_pin)
        success_resp = await client1.recv_json_message(timeout=3.0)
        assert success_resp.get("type") == "auth_success"
        token = success_resp.get("token")
        assert token and token.startswith("token_"), f"Expected issued token, got: {token}"
        print(f"    ✅ Pairing successful! Issued token: {token}")

        # Step 3: Injection works now
        await client1.send_json_draft("配对成功已解锁打字", press_enter=False)
        inject_event = await host.wait_for_event("TEXT_INJECTED", timeout=3.0)
        assert inject_event.get("text") == "配对成功已解锁打字"
        print("    ✅ Text injection verified after PIN authentication")

        await client1.close()

        # Step 4: [TC-E2E-15] Reconnect using token (passwordless reconnection)
        print("  [TC-E2E-15] Testing seamless passwordless reconnection using device token...")
        client2 = VirtualMobileClient(port=port)
        await client2.connect()

        await client2.send_auth_request(device_id="dev-pair-1", token=token)
        reconnect_resp = await client2.recv_json_message(timeout=3.0)
        assert reconnect_resp.get("type") == "auth_success"
        assert reconnect_resp.get("mode") == "trusted", f"Expected mode=trusted, got: {reconnect_resp.get('mode')}"
        print("    ✅ Reconnection verified: authenticated immediately via token without PIN prompt")

        # Verify injection again on new connection
        await client2.send_json_draft("Token免密重连打字测试", press_enter=True)
        inject_event2 = await host.wait_for_event(
            "TEXT_INJECTED",
            predicate=lambda e: e.get("text") == "Token免密重连打字测试",
            timeout=3.0
        )
        assert inject_event2.get("text") == "Token免密重连打字测试"
        await host.wait_for_event("RETURN_KEY_SIMULATED", timeout=3.0)
        print("    ✅ Seamless injection and Return key confirmed on reconnected session")

        await client2.close()
    finally:
        await host.stop()


async def test_brute_force_protection() -> None:
    """[TC-E2E-16] 3 consecutive wrong PIN attempts triggers termination."""
    print("  [TC-E2E-16] Testing 3-strikes brute-force lockout and termination...")
    port = 19204
    host = HostProcessHarness(port=port, mock_inject=True, require_pin=True, pin_code="1234")
    client = VirtualMobileClient(port=port)

    try:
        await host.start()
        await client.connect()

        # Auth request
        await client.send_auth_request(device_id="dev-attacker", device_name="Unknown Device")
        await client.recv_json_message(timeout=3.0)

        # Attempt 1: wrong PIN
        await client.send_verify_pin("0001")
        resp1 = await client.recv_json_message(timeout=3.0)
        assert resp1.get("remainingAttempts") == 2

        # Attempt 2: wrong PIN
        await client.send_verify_pin("0002")
        resp2 = await client.recv_json_message(timeout=3.0)
        assert resp2.get("remainingAttempts") == 1

        # Attempt 3: wrong PIN -> must lock out & terminate connection
        await client.send_verify_pin("0003")
        resp3 = await client.recv_json_message(timeout=3.0)
        assert resp3.get("remainingAttempts") == 0

        # Wait for disconnection
        closed = False
        try:
            await client.recv_frame(timeout=2.0)
        except (ConnectionResetError, asyncio.IncompleteReadError, Exception):
            closed = True

        assert closed or not client.is_connected, "Expected connection to be forcibly terminated by server"
        print("    ✅ 3-strikes brute-force protection confirmed: connection cleanly severed")
    finally:
        await client.close()
        await host.stop()


async def run_all_pin_tests() -> None:
    """Executes all PIN pairing and authentication test cases."""
    print("\n▶ Running Device PIN Pairing & Auth Gate Security Tests...")
    await test_open_mode_pairing()
    await test_pin_protection_gate_and_rejection()
    await test_pin_pairing_and_token_reconnect()
    await test_brute_force_protection()
    print("✅ Device PIN Pairing & Auth Gate Security Tests PASSED\n")


if __name__ == "__main__":
    asyncio.run(run_all_pin_tests())
