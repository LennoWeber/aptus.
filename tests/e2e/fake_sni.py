#!/usr/bin/python3
"""A fake tray item (StatusNotifierItem with a DBusMenu) for the S3 e2e tests, on the nested
session's private bus only (brief: never a tray item or watcher on the real session bus).

    /usr/bin/python3 tests/e2e/fake_sni.py <state-file> [--attention]

It owns `org.kde.StatusNotifierItem-<pid>-1`, serves `/StatusNotifierItem` and the menu at
`/MenuBar` (Open, a separator, More ▸ Sub item, Quit), registers with the watcher the shell
runs, and appends every call it gets (Activate, SecondaryActivate, Scroll, menu events) to
<state-file>, one line each. `--attention` starts in NeedsAttention. SIGUSR1 toggles the status.
Uses the system python3 with `gi` (GLib/Gio).
"""
from __future__ import annotations

import os
import signal
import sys

ITEM_XML = """
<node>
  <interface name="org.kde.StatusNotifierItem">
    <property name="Category" type="s" access="read"/>
    <property name="Id" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="IconPixmap" type="a(iiay)" access="read"/>
    <property name="AttentionIconName" type="s" access="read"/>
    <property name="AttentionIconPixmap" type="a(iiay)" access="read"/>
    <property name="Menu" type="o" access="read"/>
    <property name="ItemIsMenu" type="b" access="read"/>
    <property name="ToolTip" type="(sa(iiay)ss)" access="read"/>
    <method name="Activate"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
    <method name="SecondaryActivate"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
    <method name="ContextMenu"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
    <method name="Scroll"><arg type="i" direction="in"/><arg type="s" direction="in"/></method>
    <signal name="NewStatus"><arg type="s"/></signal>
    <signal name="NewTitle"/>
    <signal name="NewIcon"/>
  </interface>
</node>"""

MENU_XML = """
<node>
  <interface name="com.canonical.dbusmenu">
    <property name="Version" type="u" access="read"/>
    <property name="TextDirection" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconThemePath" type="as" access="read"/>
    <method name="GetLayout">
      <arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="as" direction="in"/>
      <arg type="u" direction="out"/><arg type="(ia{sv}av)" direction="out"/>
    </method>
    <method name="GetGroupProperties">
      <arg type="ai" direction="in"/><arg type="as" direction="in"/><arg type="a(ia{sv})" direction="out"/>
    </method>
    <method name="GetProperty">
      <arg type="i" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/>
    </method>
    <method name="Event">
      <arg type="i" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="in"/><arg type="u" direction="in"/>
    </method>
    <method name="EventGroup">
      <arg type="a(isvu)" direction="in"/><arg type="ai" direction="out"/>
    </method>
    <method name="AboutToShow"><arg type="i" direction="in"/><arg type="b" direction="out"/></method>
    <method name="AboutToShowGroup">
      <arg type="ai" direction="in"/><arg type="ai" direction="out"/><arg type="ai" direction="out"/>
    </method>
    <signal name="LayoutUpdated"><arg type="u"/><arg type="i"/></signal>
    <signal name="ItemsPropertiesUpdated"><arg type="a(ia{sv})"/><arg type="a(ias)"/></signal>
  </interface>
</node>"""

# id → (properties, children ids)
MENU = {
    0: ({"children-display": "submenu"}, [1, 2, 3, 5]),
    1: ({"label": "_Open"}, []),
    2: ({"type": "separator"}, []),
    3: ({"label": "More", "children-display": "submenu"}, [4]),
    4: ({"label": "Sub item"}, []),
    5: ({"label": "Quit"}, []),
}


def pixmap(argb: int, size: int = 22) -> tuple[int, int, bytes]:
    """One SNI icon pixmap: a filled size × size ARGB32 square in network byte order."""
    return (size, size, argb.to_bytes(4, "big") * (size * size))


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    address = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not address or f"path={runtime}/bus" in address or not os.environ.get("APTUS_TEST"):
        print("fake_sni: refusing to run outside the nested session's private bus", file=sys.stderr)
        return 3
    from gi.repository import Gio, GLib

    log = open(argv[0], "a", buffering=1)
    state = {"status": "NeedsAttention" if "--attention" in argv[1:] else "Active"}
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    name = f"org.kde.StatusNotifierItem-{os.getpid()}-1"

    def node(i: int, depth: int) -> GLib.Variant:
        props, kids = MENU[i]
        p = {k: GLib.Variant("s", v) for k, v in props.items()}
        children = [node(k, depth - 1) for k in kids] if depth != 0 else []    # av: PyGObject wraps each
        return GLib.Variant("(ia{sv}av)", (i, p, children))

    def item_call(conn, sender, path, iface, method, params, inv):
        log.write(f"{method} {params.unpack()}\n")
        inv.return_value(None)

    def item_prop(conn, sender, path, iface, prop):
        return {
            "Category": GLib.Variant("s", "ApplicationStatus"),
            "Id": GLib.Variant("s", "aptus-test-tray"),
            "Title": GLib.Variant("s", "Test tray"),
            "Status": GLib.Variant("s", state["status"]),
            "IconName": GLib.Variant("s", "dialog-information"),
            # Like a real item, an attention icon and pixmaps as well (Quickshell draws NeedsAttention
            # from the attention icon or a pixmap; without either it logs "Unable to create pixmap
            # for tray icon"). The same icon for both states: the tray test sees only the shell's
            # attention dot change.
            "IconPixmap": GLib.Variant("a(iiay)", [pixmap(0xFF3C7DD9)]),
            "AttentionIconName": GLib.Variant("s", "dialog-information"),
            "AttentionIconPixmap": GLib.Variant("a(iiay)", [pixmap(0xFF3C7DD9)]),
            "Menu": GLib.Variant("o", "/MenuBar"),
            "ItemIsMenu": GLib.Variant("b", False),
            "ToolTip": GLib.Variant("(sa(iiay)ss)", ("", [], "Test tray", "")),
        }[prop]

    def menu_call(conn, sender, path, iface, method, params, inv):
        args = params.unpack()
        if method == "GetLayout":
            parent, depth = args[0], args[1]
            log.write(f"GetLayout {parent} {depth}\n")
            inv.return_value(GLib.Variant.new_tuple(GLib.Variant("u", 1), node(parent if parent in MENU else 0, depth)))
        elif method == "GetGroupProperties":
            ids = args[0] or list(MENU)
            out = [(i, {k: GLib.Variant("s", v) for k, v in MENU[i][0].items()}) for i in ids if i in MENU]
            inv.return_value(GLib.Variant("(a(ia{sv}))", (out,)))
        elif method == "GetProperty":
            inv.return_value(GLib.Variant("(v)", (GLib.Variant("s", MENU.get(args[0], ({}, []))[0].get(args[1], "")),)))
        elif method == "Event":
            log.write(f"Event {args[0]} {args[1]}\n")
            inv.return_value(None)
        elif method == "EventGroup":
            for e in args[0]:
                log.write(f"Event {e[0]} {e[1]}\n")
            inv.return_value(GLib.Variant("(ai)", ([],)))
        elif method == "AboutToShow":
            inv.return_value(GLib.Variant("(b)", (False,)))
        elif method == "AboutToShowGroup":
            inv.return_value(GLib.Variant("(aiai)", ([], [])))
        else:
            inv.return_value(None)

    def menu_prop(conn, sender, path, iface, prop):
        return {"Version": GLib.Variant("u", 3), "TextDirection": GLib.Variant("s", "ltr"),
                "Status": GLib.Variant("s", "normal"), "IconThemePath": GLib.Variant("as", [])}[prop]

    item_info = Gio.DBusNodeInfo.new_for_xml(ITEM_XML).interfaces[0]
    menu_info = Gio.DBusNodeInfo.new_for_xml(MENU_XML).interfaces[0]
    bus.register_object("/StatusNotifierItem", item_info, item_call, item_prop, None)
    bus.register_object("/MenuBar", menu_info, menu_call, menu_prop, None)

    def toggle(*_):
        state["status"] = "Active" if state["status"] == "NeedsAttention" else "NeedsAttention"
        bus.emit_signal(None, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "NewStatus",
                        GLib.Variant("(s)", (state["status"],)))
        return True
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, toggle)

    def acquired(conn, n):
        conn.call_sync("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
                       "RegisterStatusNotifierItem", GLib.Variant("(s)", (n,)), None, Gio.DBusCallFlags.NONE, 5000, None)
        log.write("registered\n")
    Gio.bus_own_name_on_connection(bus, name, Gio.BusNameOwnerFlags.NONE, acquired, None)
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
