#!/usr/bin/env python3
"""TCP port proxy: friendly WiFi ports -> k3s TLS NodePorts on localhost."""
import os
import socket
import threading

TARGET = os.environ.get("CXADO_NODE_IP", "127.0.0.1")
MAP = {
    3000: 30300,
    8080: 30880,
    3002: 30002,
    3001: 30001,
    9091: 30091,
    8090: 30990,
    8091: 30991,
    7474: 30474,
    30080: 30080,
}


def forward(src: socket.socket, dst: socket.socket) -> None:
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client: socket.socket, remote_port: int) -> None:
    backend = None
    try:
        backend = socket.create_connection((TARGET, remote_port), timeout=10)
        t1 = threading.Thread(target=forward, args=(client, backend), daemon=True)
        t2 = threading.Thread(target=forward, args=(backend, client), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except OSError:
        pass
    finally:
        for s in (client, backend):
            if s is not None:
                try:
                    s.close()
                except OSError:
                    pass


def serve(local_port: int, remote_port: int) -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", local_port))
    sock.listen(128)
    while True:
        client, _ = sock.accept()
        threading.Thread(target=handle, args=(client, remote_port), daemon=True).start()


if __name__ == "__main__":
    for local, remote in MAP.items():
        threading.Thread(target=serve, args=(local, remote), daemon=True).start()
    threading.Event().wait()
