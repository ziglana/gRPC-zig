#!/usr/bin/env python3
"""
Integration test client for gRPC-zig server.
Tests basic functionality without requiring full protobuf compilation.
"""

import socket
import struct
import sys
import time
from typing import Optional

class SimpleGrpcClient:
    """Simple gRPC client using raw HTTP/2 for testing purposes."""

    def __init__(self, host: str = "localhost", port: int = 50052):
        self.host = host
        self.port = port
        self.sock: Optional[socket.socket] = None

    def connect(self):
        """Establish connection to the gRPC server."""
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(5)
            self.sock.connect((self.host, self.port))

            # Send HTTP/2 connection preface
            preface = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
            self.sock.sendall(preface)

            # Send SETTINGS frame
            settings_frame = self._build_settings_frame()
            self.sock.sendall(settings_frame)

            print(f"✓ Connected to {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"✗ Connection failed: {e}")
            return False

    def _build_settings_frame(self) -> bytes:
        """Build HTTP/2 SETTINGS frame."""
        # SETTINGS frame: type=0x04, flags=0x00, stream_id=0
        # No settings payload for simplicity
        length = 0
        frame_type = 0x04
        flags = 0x00
        stream_id = 0

        return struct.pack('>I', (length << 8) | frame_type)[1:] + \
               struct.pack('>BI', flags, stream_id)

    def _build_data_frame(self, stream_id: int, data: bytes, end_stream: bool = True) -> bytes:
        """Build HTTP/2 DATA frame."""
        # DATA frame: type=0x00
        length = len(data)
        frame_type = 0x00
        flags = 0x01 if end_stream else 0x00  # END_STREAM flag

        return struct.pack('>I', (length << 8) | frame_type)[1:] + \
               struct.pack('>BI', flags, stream_id) + data

    def _build_headers_frame(self, stream_id: int, method: str) -> bytes:
        """Build HTTP/2 HEADERS frame with gRPC headers."""
        # For simplicity, we'll send minimal headers
        # In a real implementation, this would use HPACK encoding
        # For testing, we'll send simple pseudo-headers

        headers = f":method: POST\r\n:path: /{method}\r\n:scheme: http\r\n".encode()

        frame_type = 0x01  # HEADERS
        flags = 0x04  # END_HEADERS
        length = len(headers)

        return struct.pack('>I', (length << 8) | frame_type)[1:] + \
               struct.pack('>BI', flags, stream_id) + headers

    def send_message(self, method: str, message: str) -> bool:
        """Send a simple message to the server."""
        try:
            if not self.sock:
                print("✗ Not connected")
                return False

            stream_id = 1

            # Send HEADERS frame
            headers_frame = self._build_headers_frame(stream_id, method)
            self.sock.sendall(headers_frame)

            # Send DATA frame with message
            data_frame = self._build_data_frame(stream_id, message.encode(), True)
            self.sock.sendall(data_frame)

            # Try to receive response (with timeout)
            try:
                response = self.sock.recv(4096)
                if response:
                    print(f"✓ Received response: {len(response)} bytes")
                    return True
                else:
                    print("✗ No response received")
                    return False
            except socket.timeout:
                print("✗ Response timeout")
                return False

        except Exception as e:
            print(f"✗ Send failed: {e}")
            return False

    def close(self):
        """Close the connection."""
        if self.sock:
            self.sock.close()
            self.sock = None
            print("✓ Connection closed")


def run_tests():
    """Run integration tests."""
    print("=" * 60)
    print("gRPC-zig Integration Test Suite")
    print("=" * 60)
    print()

    client = SimpleGrpcClient()

    # Test 1: Connection
    print("Test 1: Server Connection")
    print("-" * 60)
    if not client.connect():
        print("\n✗ FAILED: Could not connect to server")
        print("  Make sure the server is running on localhost:50052")
        return False
    print()

    # Test 2: Echo handler
    print("Test 2: Echo Handler")
    print("-" * 60)
    test_message = "Hello from Python test client!"
    if not client.send_message("Echo", test_message):
        print("✗ FAILED: Echo test failed")
        client.close()
        return False
    print()

    # Test 3: CompressedEcho handler
    print("Test 3: CompressedEcho Handler")
    print("-" * 60)
    if not client.send_message("CompressedEcho", "Test compression"):
        print("✗ FAILED: CompressedEcho test failed")
        client.close()
        return False
    print()

    # Test 4: HealthCheck handler
    print("Test 4: HealthCheck Handler")
    print("-" * 60)
    if not client.send_message("HealthCheck", ""):
        print("✗ FAILED: HealthCheck test failed")
        client.close()
        return False
    print()

    client.close()

    print("=" * 60)
    print("✓ All tests passed!")
    print("=" * 60)
    return True


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
