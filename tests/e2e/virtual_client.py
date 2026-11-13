"""
Virtual Mobile Client (iOS/Android Simulator) for Vocal E2E Integration Tests.
Zero-dependency, pure Python 3 standard library implementation of RFC 6455 WebSocket Client.
"""

import asyncio
import base64
import hashlib
import json
import os
import re
import socket
import struct
import subprocess
from typing import Optional, Tuple, Dict, Any

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

OPCODE_CONT = 0x0
OPCODE_TEXT = 0x1
OPCODE_BINARY = 0x2
OPCODE_CLOSE = 0x8
OPCODE_PING = 0x9
OPCODE_PONG = 0xA


class VirtualMobileClient:
    """Simulates an iOS or Android client connecting to VocalHost via WebSocket."""

    def __init__(self, host: str = "127.0.0.1", port: int = 8888):
        self.host = host
        self.port = port
        self.reader: Optional[asyncio.StreamReader] = None
        self.writer: Optional[asyncio.StreamWriter] = None
        self.is_connected = False
        self._raw_sock: Optional[socket.socket] = None

    async def connect(self, timeout: float = 5.0) -> None:
        """Establishes TCP connection and performs RFC 6455 WebSocket Handshake."""
        connect_coro = asyncio.open_connection(self.host, self.port)
        self.reader, self.writer = await asyncio.wait_for(connect_coro, timeout=timeout)
        self._raw_sock = self.writer.get_extra_info('socket')

        # Generate WebSocket key
        sec_key = base64.b64encode(os.urandom(16)).decode('utf-8')
        expected_accept = base64.b64encode(
            hashlib.sha1((sec_key + WS_GUID).encode('utf-8')).digest()
        ).decode('utf-8')

        handshake_req = (
            f"GET / HTTP/1.1\r\n"
            f"Host: {self.host}:{self.port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {sec_key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n"
            f"User-Agent: VocalVirtualClient/1.0\r\n"
            f"\r\n"
        )
        self.writer.write(handshake_req.encode('utf-8'))
        await self.writer.drain()

        # Read HTTP handshake response
        response_bytes = await asyncio.wait_for(self._read_http_headers(), timeout=timeout)
        response_text = response_bytes.decode('utf-8', errors='replace')

        first_line = response_text.splitlines()[0] if response_text else ""
        if "101" not in first_line:
            raise ConnectionError(f"Handshake failed: expected HTTP 101, got: {first_line}")

        # Check Sec-WebSocket-Accept
        accept_match = re.search(r"Sec-WebSocket-Accept:\s*(\S+)", response_text, re.IGNORECASE)
        if not accept_match or accept_match.group(1).strip() != expected_accept:
            raise ConnectionError(
                f"Handshake failed: invalid Sec-WebSocket-Accept. Expected: {expected_accept}, got: {accept_match.group(1) if accept_match else 'None'}"
            )

        self.is_connected = True

    async def _read_http_headers(self) -> bytes:
        """Reads until HTTP delimiter CRLF CRLF."""
        buffer = bytearray()
        while b"\r\n\r\n" not in buffer:
            chunk = await self.reader.read(512)
            if not chunk:
                break
            buffer.extend(chunk)
        return bytes(buffer)

    def _build_frame(self, opcode: int, payload: bytes) -> bytes:
        """Builds an RFC 6455 masked WebSocket frame (Client -> Server MUST be masked)."""
        header = bytearray()
        # Fin bit = 1 (0x80) | opcode
        header.append(0x80 | (opcode & 0x0F))

        length = len(payload)
        mask_bit = 0x80  # Client MUST mask

        if length <= 125:
            header.append(mask_bit | length)
        elif length <= 65535:
            header.append(mask_bit | 126)
            header.extend(struct.pack("!H", length))
        else:
            header.append(mask_bit | 127)
            header.extend(struct.pack("!Q", length))

        # 4-byte random masking key
        mask_key = os.urandom(4)
        header.extend(mask_key)

        # Mask payload with XOR
        masked_payload = bytearray(length)
        for i in range(length):
            masked_payload[i] = payload[i] ^ mask_key[i % 4]

        return bytes(header) + bytes(masked_payload)

    async def send_text(self, text: str) -> None:
        """Sends a WebSocket text frame (Opcode 0x1)."""
        if not self.is_connected or not self.writer:
            raise ConnectionError("Client is not connected.")
        frame = self._build_frame(OPCODE_TEXT, text.encode('utf-8'))
        self.writer.write(frame)
        await self.writer.drain()

    async def send_json_draft(self, text: str, press_enter: bool = False) -> None:
        """Sends structured JSON text payload according to Vocal protocol."""
        payload = json.dumps({
            "type": "text",
            "text": text,
            "pressEnter": press_enter
        }, ensure_ascii=False)
        await self.send_text(payload)

    async def send_auth_request(self, device_id: str = "test_device_uuid", device_name: str = "Virtual Client", token: str = "") -> None:
        """Sends auth_request handshake payload."""
        payload = json.dumps({
            "type": "auth_request",
            "deviceId": device_id,
            "deviceName": device_name,
            "token": token
        })
        await self.send_text(payload)

    async def send_verify_pin(self, pin: str) -> None:
        """Submits PIN for verification."""
        payload = json.dumps({
            "type": "auth_verify_pin",
            "pin": pin
        })
        await self.send_text(payload)

    async def recv_json_message(self, timeout: float = 5.0) -> Dict[str, Any]:
        """Receives next text frame and deserializes JSON."""
        raw = await self.recv_text(timeout=timeout)
        return json.loads(raw)

    async def send_pong(self) -> None:
        """Sends a Pong frame (Opcode 0xA) or JSON pong according to Vocal protocol."""
        # Vocal protocol supports JSON pong: {"type":"pong"}
        await self.send_text(json.dumps({"type": "pong"}))

    async def recv_frame(self, timeout: float = 5.0) -> Tuple[int, bytes]:
        """Receives a single WebSocket frame from server."""
        if not self.is_connected or not self.reader:
            raise ConnectionError("Client is not connected.")

        async def _read_exact(n: int) -> bytes:
            data = await self.reader.readexactly(n)
            return data

        header_coro = _read_exact(2)
        header = await asyncio.wait_for(header_coro, timeout=timeout)

        first_byte, second_byte = header[0], header[1]
        fin = (first_byte & 0x80) != 0
        opcode = first_byte & 0x0F
        is_masked = (second_byte & 0x80) != 0
        payload_len = second_byte & 0x7F

        if payload_len == 126:
            ext_len_bytes = await asyncio.wait_for(_read_exact(2), timeout=timeout)
            payload_len = struct.unpack("!H", ext_len_bytes)[0]
        elif payload_len == 127:
            ext_len_bytes = await asyncio.wait_for(_read_exact(8), timeout=timeout)
            payload_len = struct.unpack("!Q", ext_len_bytes)[0]

        mask_key = None
        if is_masked:
            mask_key = await asyncio.wait_for(_read_exact(4), timeout=timeout)

        payload = b""
        if payload_len > 0:
            payload = await asyncio.wait_for(_read_exact(payload_len), timeout=timeout)
            if is_masked and mask_key:
                unmasked = bytearray(payload_len)
                for i in range(payload_len):
                    unmasked[i] = payload[i] ^ mask_key[i % 4]
                payload = bytes(unmasked)

        return opcode, payload

    async def recv_text(self, timeout: float = 5.0) -> str:
        """Receives the next text frame content as string."""
        opcode, payload = await self.recv_frame(timeout=timeout)
        if opcode == OPCODE_CLOSE:
            self.is_connected = False
            raise ConnectionResetError("Server closed connection.")
        return payload.decode('utf-8', errors='replace')

    async def close(self, code: int = 1000) -> None:
        """Performs normal WebSocket close sequence."""
        if self.is_connected and self.writer:
            try:
                close_payload = struct.pack("!H", code)
                frame = self._build_frame(OPCODE_CLOSE, close_payload)
                self.writer.write(frame)
                await self.writer.drain()
            except Exception:
                pass
            finally:
                self.is_connected = False
                self.writer.close()
                await self.writer.wait_closed()

    def abort(self) -> None:
        """Abruptly terminates the TCP connection (simulates sudden WiFi loss / network crash)."""
        self.is_connected = False
        if self._raw_sock:
            try:
                # Force TCP RST
                self._raw_sock.setsockopt(
                    socket.SOL_SOCKET,
                    socket.SO_LINGER,
                    struct.pack('ii', 1, 0)
                )
                self._raw_sock.close()
            except Exception:
                pass
        if self.writer:
            try:
                self.writer.close()
            except Exception:
                pass


def check_mdns_discovery(expected_port: int, timeout_sec: float = 3.0) -> Tuple[bool, str]:
    """
    Verifies Bonjour / mDNS service discovery on macOS using `dns-sd -B _vocal _tcp`.
    Returns (success, description).
    """
    try:
        proc = subprocess.Popen(
            ["dns-sd", "-B", "_vocal", "_tcp"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        try:
            # Poll stdout for lines matching Vocal service
            output, _ = proc.communicate(timeout=timeout_sec)
        except subprocess.TimeoutExpired:
            proc.kill()
            output, _ = proc.communicate()

        lines = output.splitlines()
        found_service = False
        service_name = ""
        for line in lines:
            if "Add" in line and "_vocal._tcp" in line:
                found_service = True
                service_name = line.split()[-1]
                break

        if found_service:
            return True, f"Found Bonjour service: {service_name}"
        else:
            return False, f"dns-sd did not discover _vocal._tcp service within {timeout_sec}s"
    except Exception as e:
        return False, f"mDNS check error: {e}"

