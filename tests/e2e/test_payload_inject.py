"""
E2E Test: Payload format, text injection, return key simulation, and plain text fallback.
Corresponds to TC-E2E-04, TC-E2E-05, and TC-E2E-06 in e2e-testing-architecture.md.
"""

import asyncio
from typing import Dict, Any

from tests.e2e.host_process import HostProcessHarness
from tests.e2e.virtual_client import VirtualMobileClient


async def test_structured_text_injection_without_enter(port: int = 19201) -> None:
    """TC-E2E-04: Structured JSON payload with pressEnter=false."""
    print("  [TC-E2E-04] Testing structured text injection without Enter key...")
    harness = HostProcessHarness(port=port)
    client = VirtualMobileClient(host="127.0.0.1", port=port)

    try:
        await harness.start()
        await client.connect(timeout=5.0)

        sample_text = "你好 Vocal 智能键盘"
        await client.send_json_draft(sample_text, press_enter=False)

        # 1. Assert PAYLOAD_RECEIVED
        payload_ev = await harness.wait_for_event(
            "PAYLOAD_RECEIVED",
            predicate=lambda e: e.get("mode") == "JSON",
            timeout=5.0
        )
        assert payload_ev["mode"] == "JSON", f"Expected mode JSON, got: {payload_ev}"

        # 2. Assert TEXT_INJECTED
        inject_ev = await harness.wait_for_event(
            "TEXT_INJECTED",
            predicate=lambda e: e.get("text") == sample_text,
            timeout=5.0
        )
        assert inject_ev["text"] == sample_text, f"Text mismatch: {inject_ev}"
        assert inject_ev.get("mocked") is True, f"Expected mocked: true in test mode"
        print(f"    ✅ Text injection verified: '{sample_text}' ({inject_ev.get('charCount')} chars)")

        # 3. Assert NO RETURN_KEY_SIMULATED event was fired
        await asyncio.sleep(0.3)
        return_events = [e for e in harness.events if e.get("vocal_event") == "RETURN_KEY_SIMULATED"]
        assert len(return_events) == 0, f"Expected NO return key simulated, but found: {return_events}"
        print("    ✅ Confirmed NO return key event was simulated when pressEnter=false")

    finally:
        if client.is_connected:
            await client.close()
        await harness.stop()


async def test_structured_text_injection_with_enter(port: int = 19202) -> None:
    """TC-E2E-05: Structured JSON payload with pressEnter=true."""
    print("  [TC-E2E-05] Testing structured text injection with Enter key (pressEnter=true)...")
    harness = HostProcessHarness(port=port)
    client = VirtualMobileClient(host="127.0.0.1", port=port)

    try:
        await harness.start()
        await client.connect(timeout=5.0)

        cmd_text = "git commit -m '自动注入测试'"
        await client.send_json_draft(cmd_text, press_enter=True)

        # 1. Assert TEXT_INJECTED
        inject_ev = await harness.wait_for_event(
            "TEXT_INJECTED",
            predicate=lambda e: e.get("text") == cmd_text,
            timeout=5.0
        )
        assert inject_ev["text"] == cmd_text, f"Text mismatch: {inject_ev}"

        # 2. Assert RETURN_KEY_SIMULATED
        return_ev = await harness.wait_for_event(
            "RETURN_KEY_SIMULATED",
            predicate=lambda e: e.get("mocked") is True,
            timeout=5.0
        )
        assert return_ev is not None, "RETURN_KEY_SIMULATED event was not emitted"
        print(f"    ✅ Text injection and Return key simulation verified for: '{cmd_text}'")

    finally:
        if client.is_connected:
            await client.close()
        await harness.stop()


async def test_plain_text_backward_compatibility(port: int = 19203) -> None:
    """TC-E2E-06: Plain non-JSON text fallback injection (backward compatibility)."""
    print("  [TC-E2E-06] Testing plain text backward compatibility (non-JSON payload)...")
    harness = HostProcessHarness(port=port)
    client = VirtualMobileClient(host="127.0.0.1", port=port)

    try:
        await harness.start()
        await client.connect(timeout=5.0)

        plain_text = "Legacy plain text string without JSON brackets"
        await client.send_text(plain_text)

        # 1. Assert PAYLOAD_RECEIVED with mode == PLAIN_TEXT
        payload_ev = await harness.wait_for_event(
            "PAYLOAD_RECEIVED",
            predicate=lambda e: e.get("mode") == "PLAIN_TEXT",
            timeout=5.0
        )
        assert payload_ev["mode"] == "PLAIN_TEXT", f"Expected mode PLAIN_TEXT, got: {payload_ev}"

        # 2. Assert TEXT_INJECTED
        inject_ev = await harness.wait_for_event(
            "TEXT_INJECTED",
            predicate=lambda e: e.get("text") == plain_text,
            timeout=5.0
        )
        assert inject_ev["text"] == plain_text, f"Text mismatch: {inject_ev}"

        # 3. Connection must still be alive and accept next message
        next_text = "Next message after legacy fallback"
        await client.send_json_draft(next_text, press_enter=False)
        next_ev = await harness.wait_for_event(
            "TEXT_INJECTED",
            predicate=lambda e: e.get("text") == next_text,
            timeout=5.0
        )
        assert next_ev["text"] == next_text, "Subsequent message failed after plain text fallback"
        print("    ✅ Backward compatibility verified: smooth fallback without connection disruption")

    finally:
        if client.is_connected:
            await client.close()
        await harness.stop()


async def run_payload_inject_tests(base_port: int = 19200) -> bool:
    """Executes all payload injection and format tests."""
    print("\n▶ Running Payload Format & Injection Assertion Tests...")
    try:
        await test_structured_text_injection_without_enter(port=base_port + 1)
        await test_structured_text_injection_with_enter(port=base_port + 2)
        await test_plain_text_backward_compatibility(port=base_port + 3)
        print("✅ Payload Format & Injection Assertion Tests PASSED\n")
        return True
    except Exception as e:
        print(f"❌ Payload Format & Injection Assertion Tests FAILED: {e}\n")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    asyncio.run(run_payload_inject_tests())

