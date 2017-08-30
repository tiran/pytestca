#!/usr/bin/env python3
import pprint
import socket
import ssl
import threading

clientctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
clientctx.verify_mode = ssl.CERT_REQUIRED
clientctx.check_hostname = True
clientctx.verify_flags |= ssl.VERIFY_CRL_CHECK_CHAIN
clientctx.load_verify_locations(capath='out/capath')
clientctx.load_cert_chain('out/client-combined.pem')

serverctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
serverctx.verify_mode = ssl.CERT_REQUIRED
serverctx.verify_flags |= ssl.VERIFY_CRL_CHECK_CHAIN
serverctx.load_verify_locations(capath='out/capath')
serverctx.load_cert_chain('out/allsans-combined.passwd.pem', password=b'somepass')


def server(server_sock, out):
    server_sock.listen(1)
    server_ssock = serverctx.wrap_socket(server_sock, server_side=True)
    ssock, _ = server_ssock.accept()
    out.append(['client cert', ssock.getpeercert()])
    ssock.read()
    ssock.close()


def client(address, out):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.connect(address)
        ssock = clientctx.wrap_socket(sock, server_hostname='localhost')
        out.append(['server cert', ssock.getpeercert()])
        ssock.write(b'hello')


if __name__ == '__main__':
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.bind(('', 0))
    address = server_sock.getsockname()
    out = []
    threads = [
        threading.Thread(target=server, args=(server_sock, out)),
        threading.Thread(target=client, args=(address, out)),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    pprint.pprint(out)
