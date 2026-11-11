#!/usr/bin/env python3
"""Minimal Wayland virtual pointer (zwlr_virtual_pointer_v1) over the raw wire protocol.

Usage: vpointer.py <wayland-socket> click X Y [W H]    (absolute, in output pixels)
       vpointer.py <wayland-socket> rclick X Y [W H]   (the right button)
       vpointer.py <wayland-socket> move X Y [W H]
Only ever point it at a nested compositor's socket.
"""
import os
import socket
import struct
import sys
import time


class Wire:
    def __init__(self, path):
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(path)
        self.next_id = 2
        self.buf = b""

    def new_id(self):
        i = self.next_id
        self.next_id += 1
        return i

    def send(self, obj, opcode, payload=b""):
        size = 8 + len(payload)
        self.s.sendall(struct.pack("<II", obj, (size << 16) | opcode) + payload)

    @staticmethod
    def string(text):
        b = text.encode() + b"\0"
        pad = (4 - len(b) % 4) % 4
        return struct.pack("<I", len(b)) + b + b"\0" * pad

    def read_events(self, until_sync_id):
        events = []
        while True:
            while len(self.buf) < 8:
                self.buf += self.s.recv(65536)
            obj, word = struct.unpack("<II", self.buf[:8])
            size, opcode = word >> 16, word & 0xFFFF
            while len(self.buf) < size:
                self.buf += self.s.recv(65536)
            body, self.buf = self.buf[8:size], self.buf[size:]
            events.append((obj, opcode, body))
            if obj == until_sync_id and opcode == 0:
                return events


def main():
    sock = sys.argv[1]
    if not sock.startswith("/"):
        sock = os.path.join(os.environ["XDG_RUNTIME_DIR"], sock)
    cmd, x, y = sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    w = int(sys.argv[5]) if len(sys.argv) > 5 else 1920
    h = int(sys.argv[6]) if len(sys.argv) > 6 else 1080
    c = Wire(sock)
    registry = c.new_id()
    c.send(1, 1, struct.pack("<I", registry))          # wl_display.get_registry
    cb = c.new_id()
    c.send(1, 0, struct.pack("<I", cb))                # wl_display.sync
    mgr_name = None
    for obj, op, body in c.read_events(cb):
        if obj == registry and op == 0:
            name, ln = struct.unpack("<II", body[:8])
            iface = body[8:8 + ln - 1].decode()
            if iface == "zwlr_virtual_pointer_manager_v1":
                mgr_name = name
    if mgr_name is None:
        sys.exit("no zwlr_virtual_pointer_manager_v1")
    mgr = c.new_id()
    c.send(registry, 0, struct.pack("<I", mgr_name) + Wire.string("zwlr_virtual_pointer_manager_v1")
           + struct.pack("<II", 1, mgr))               # wl_registry.bind
    ptr = c.new_id()
    c.send(mgr, 0, struct.pack("<II", 0, ptr))          # create_virtual_pointer(seat=null)
    t = int(time.monotonic() * 1000) & 0xFFFFFFFF
    c.send(ptr, 1, struct.pack("<IIIII", t, x, y, w, h))  # motion_absolute
    c.send(ptr, 4, struct.pack("<I", t))                 # frame
    if cmd in ("click", "rclick"):
        btn = 0x110 if cmd == "click" else 0x111                 # BTN_LEFT / BTN_RIGHT
        time.sleep(0.05)
        c.send(ptr, 2, struct.pack("<III", t + 50, btn, 1))     # pressed
        c.send(ptr, 4, struct.pack("<I", t + 50))
        time.sleep(0.03)
        c.send(ptr, 2, struct.pack("<III", t + 80, btn, 0))     # released
        c.send(ptr, 4, struct.pack("<I", t + 80))
    cb = c.new_id()
    c.send(1, 0, struct.pack("<I", cb))
    c.read_events(cb)
    c.send(ptr, 8)                                       # destroy
    time.sleep(0.05)


if __name__ == "__main__":
    main()
