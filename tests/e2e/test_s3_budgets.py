"""S3 budgets (07 §12) measured in the nested session: shell RSS, idle CPU and wakeups, frame times
of the notch under a toast burst and an OSD burst. Reported in PHASES.md; the test fails only
beyond the budget."""
from __future__ import annotations

import os
import time

from nested import Nested
from s3bus import notify, shell_pid

TICK = os.sysconf("SC_CLK_TCK")


def cpu_ticks(pid: int) -> int:
    f = open(f"/proc/{pid}/stat").read().rsplit(")", 1)[1].split()
    return int(f[11]) + int(f[12])                  # utime + stime


def main_thread_switches(pid: int) -> int:
    """Context switches of the GUI thread (each wakeup is one): voluntary and involuntary."""
    s = open(f"/proc/{pid}/task/{pid}/status").read()
    return sum(int(l.split()[1]) for l in s.splitlines() if "ctxt_switches:" in l)


def rss_mb(pid: int) -> float:
    for l in open(f"/proc/{pid}/status"):
        if l.startswith("VmRSS:"):
            return int(l.split()[1]) / 1024
    return 0.0


def test_idle_rss_cpu_and_wakeups(nested: Nested, record_property) -> None:
    """07 §12 averages over minutes: a 60 s window holds exactly one clock minute roll (M-34,
    about 70–90 main-thread switches), as every minute at rest does; a 30 s window held one
    only half the time."""
    pid = shell_pid(nested)
    time.sleep(5)                                    # let the start settle
    t0, c0, w0 = time.monotonic(), cpu_ticks(pid), main_thread_switches(pid)
    time.sleep(60)
    t1, c1, w1 = time.monotonic(), cpu_ticks(pid), main_thread_switches(pid)
    cpu = (c1 - c0) / TICK / (t1 - t0) * 100
    wakeups = (w1 - w0) / (t1 - t0)
    rss = rss_mb(pid)
    for k, v in (("cpu_percent", cpu), ("main_wakeups_per_s", wakeups), ("rss_mb", rss)):
        record_property(k, round(v, 2))
    print(f"S3 idle: cpu {cpu:.2f} %, main thread {wakeups:.2f} wakeups/s, rss {rss:.0f} MB")
    assert cpu < 0.3
    assert wakeups <= 2
    assert rss <= 260


def test_frame_times_under_toasts_and_osd(nested: Nested, record_property) -> None:
    """CPU of the shell while the notch animates (a toast burst, then 20 volume steps): the budget
    is the frame time; CPU per second of animation is its stand-in here (the GPU side is P-21)."""
    pid = shell_pid(nested)
    c0, t0 = cpu_ticks(pid), time.monotonic()
    for i in range(5):
        notify(nested, f"Burst {i}", "", "-a", f"Burst{i}")
        time.sleep(0.2)
    for _ in range(20):
        nested.shortcut("vol-up" if _ % 2 else "vol-down")
        time.sleep(0.05)
    time.sleep(1.5)
    cpu = (cpu_ticks(pid) - c0) / TICK / (time.monotonic() - t0) * 100
    record_property("animation_cpu_percent", round(cpu, 1))
    print(f"S3 animation: shell cpu {cpu:.1f} % of one core")
    assert cpu < 50                                  # one core is the budget's ceiling (8 ms of 16.7)
