#!/usr/bin/env python3
import pprint
import socket
import ssl
import sys
import threading

OP_NO_TLSv1_3 = getattr(ssl, 'OP_NO_TLSv1_3', 0)

clientctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
clientctx.verify_mode = ssl.CERT_REQUIRED
clientctx.check_hostname = True
clientctx.options |= OP_NO_TLSv1_3
clientctx.verify_flags |= ssl.VERIFY_CRL_CHECK_CHAIN
clientctx.load_verify_locations(capath='out/capath')
clientctx.load_cert_chain('out/client-combined.rsa.pem')

serverctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
serverctx.verify_mode = ssl.CERT_REQUIRED
serverctx.verify_flags |= ssl.VERIFY_CRL_CHECK_CHAIN
serverctx.options |= OP_NO_TLSv1_3
serverctx.load_verify_locations(capath='out/capath')
# context can load ECC and RSA certs at the same time
serverctx.load_cert_chain('out/allsans-combined.passwd.rsa.pem', password=b'somepass')
serverctx.load_cert_chain('out/allsans-combined.passwd.ecc.pem', password=b'somepass')


def server(ctx, server_sock, out):
    server_sock.listen(1)
    server_ssock = ctx.wrap_socket(server_sock, server_side=True)
    ssock, _ = server_ssock.accept()
    with ssock:
        ssock.read()
        out.append(['client cert', ssock.getpeercert()])


def client(ctx, address, out):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.connect(address)
        ssock = ctx.wrap_socket(sock, server_hostname='localhost')
        ssock.write(b'hello')
        out.append(['server cert', ssock.getpeercert()])


def conntest(serverctx, clientctx):
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        server_sock.bind(('', 0))
        address = server_sock.getsockname()
        out = []
        threads = [
            threading.Thread(target=server, args=(serverctx, server_sock, out)),
            threading.Thread(target=client, args=(clientctx, address, out)),
        ]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
    finally:
        server_sock.close()
    return out


if __name__ == '__main__':
    out = []
    clientctx.set_ciphers('DEFAULT:!ECDSA')
    out.extend(conntest(serverctx, clientctx))
    clientctx.set_ciphers('DEFAULT:!RSA')
    out.extend(conntest(serverctx, clientctx))
    pprint.pprint(out)
    if len(out) != 4:
        sys.exit("Failure")
    # 2x client, 1x RSA server cert, 1x ECC server cert
    serials = set(o[1]['serialNumber'] for o in out)
    if len(serials) != 3:
        sys.exit("Failure")
