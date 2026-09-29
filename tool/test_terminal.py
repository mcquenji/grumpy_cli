"""POSIX PTY integration tests. Pass a compiled test/terminal/fixtures/terminal_probe.dart."""
import fcntl
import struct
import json
import os
import pty
import select
import subprocess
import sys
import termios
import time


def run(binary, ansi, cancel=False):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
    before = termios.tcgetattr(slave)
    process = subprocess.Popen(
        [binary], stdin=slave, stdout=subprocess.PIPE, stderr=slave,
        env={**os.environ, 'TERM': 'xterm-256color' if ansi else 'dumb'},
    )
    seen = bytearray()
    cursor = 0

    def until(marker):
        nonlocal cursor
        limit = time.monotonic() + 5
        marker = marker.encode()
        while marker not in seen[cursor:]:
            if time.monotonic() > limit:
                raise AssertionError(f'Timed out waiting for {marker!r}: {seen!r}')
            if select.select([master], [], [], 0.05)[0]:
                seen.extend(os.read(master, 65536))
        cursor = seen.index(marker, cursor) + len(marker)

    def send(value):
        os.write(master, value)

    try:
        until('Name:')
        send('Grümpy\n'.encode())
        until('Password:')
        assert not termios.tcgetattr(slave)[3] & termios.ECHO
        send(b'super-secret\n')
        until('Choose one')
        if cancel:
            if ansi:
                until('Enter select')
                send(b'\x1b')
            else:
                send(b'\x04')
        elif ansi:
            until('Enter select')
            send(b'\x1b[B\r')
            until('Choose many')
            until('Enter confirm')
            send(b'\x1b[B \x1b[A \r')
        else:
            until('Selection')
            send(b'3\n')
            until('Selections')
            send(b'3,1\n')
        output = process.communicate(timeout=5)[0]
        while select.select([master], [], [], 0)[0]:
            seen.extend(os.read(master, 65536))
        assert b'super-secret' not in seen, seen
        assert termios.tcgetattr(slave) == before, 'Terminal modes were not restored'
        assert process.returncode == (130 if cancel else 0), (process.returncode, seen)
        if not cancel:
            assert json.loads(output) == {
                'name': 'Grümpy', 'passwordLength': 12,
                'selected': 3, 'multiple': [1, 3],
            }, output
        if ansi:
            assert b'\x1b[?25h' in seen, 'Cursor was not restored'
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)
        os.close(slave)


if __name__ == '__main__':
    for keyboard in (False, True):
        for cancelled in (False, True):
            run(os.path.abspath(sys.argv[1]), keyboard, cancelled)
    print('4 native terminal tests passed (line/keyboard, success/cancellation).')
