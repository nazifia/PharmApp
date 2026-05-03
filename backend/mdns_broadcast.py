#!/usr/bin/env python
"""Broadcast PharmApp server via mDNS so Flutter devices can auto-discover it."""
import socket
import time
import sys

try:
    from zeroconf import Zeroconf, ServiceInfo
except ImportError:
    print("ERROR: zeroconf not installed. Run: pip install zeroconf")
    sys.exit(1)


def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        return s.getsockname()[0]
    finally:
        s.close()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    local_ip = get_local_ip()

    info = ServiceInfo(
        '_pharmapp._tcp.local.',
        'PharmApp._pharmapp._tcp.local.',
        addresses=[socket.inet_aton(local_ip)],
        port=port,
        properties={b'path': b'/api'},
    )

    zc = Zeroconf()
    zc.register_service(info)
    print(f"[mDNS] Broadcasting: PharmApp @ {local_ip}:{port}/api")
    print("[mDNS] Devices with the app can now auto-discover this server.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        zc.unregister_service(info)
        zc.close()
        print("[mDNS] Service unregistered.")


if __name__ == '__main__':
    main()
