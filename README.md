# New CA for Python tests

## CA certs and CRLs

All CAs use 2048bits RSA keys with exponent 65537.

```
cacert.crt
pyrootca.crl
pyrootca.crt
pyrootca-untrustedserver.crt
pysubca.crl
pysubca.crt
```

Root CA and all CRLs are also available as ``capath`` directory.

```
capath/5be189af.r0
capath/4c69e26e.r0
capath/4c69e26e.0
capath/99d0fa06.0
```

## end entity certs

```
allsans-badcert.rsa.pem
allsans-badkey.rsa.pem
allsans-chain.rsa.pem
allsans-combined.ecc.pem
allsans-combined.passwd.ecc.pem
allsans-combined.passwd.rsa.pem
allsans-combined.rsa.pem
allsans.ecc.crt
allsans.ecc.key
allsans-mismatchkey.rsa.pem
allsans.rsa.crt
allsans.rsa.key
client-combined.rsa.pem
dhparam1024.pem
dhparam2048.pem
dhparam512.pem
idna2003-combined.rsa.pem
idna2008-combined.rsa.pem
localhost-cnonly-combined.rsa.pem
localhost-combined.rsa.pem
localip-combined.rsa.pem
revoked-combined.rsa.pem
wildcards-combined.rsa.pem
```

## DH params

```
dhparam512.pem
dhparam1024.pem
dhparam2048.pem
```

## suffixes

``rsa`` certs are RSA key with 2048bits key size. ``ecc`` are elliptic curve keys with
``prime256v1`` curve.

<dl>
  <dt><code>*.rsa.crt</code>, <code>*.ecc.crt</code></dt>
  <dd>single X.509 cert (PEM encoded)</dd>
  <dt><code>*.-untrustedserver.crt</code></dt>
  <dd>Trusted X.509 root certificate with <code>-addreject serverAuth</code></dd>
  <dt><code>*.rsa.key</code>, <code>*.ecc.key</code></dt>
  <dd>private key (PEM encoded)</dd>
  <dt><code>*.passwd.rsa.key</code>, <code>*.passwd.ecc.key</code></dt>
  <dd>encrypted private key (PEM encoded), password: <code>somepass</code></dd>
  <dt><code>*.crl</code></dt>
  <dd>Certificate Revocation List (PEM encoded)</dd>
  <dt><code>*-chain.rsa.pem</code>, <code>*-chain.ecc.pem</code></dt>
  <dd>cert, intermediate CA</dd>
  <dt><code>*-combined.rsa.pem</code>, <code>*-combined.ecc.pem</code></dt>
  <dd>key, cert, intermediate CA</dd>
  <dt><code>*-combined.passwd.rsa.pem</code>, <code>*-combined.passwd.ecc.pem</code></dt>
  <dd>encrypted key, cert, intermediate CA</dd>
  <dt><code>*-badcert.rsa.pem</code></dt>
  <dd>key, cert, bad intermediate CA</dd>
  <dt><code>*-badkey.rsa.pem</code></dt>
  <dd>bad key, cert, intermediate CA</dd>
  <dt><code>*-badcert.rsa.pem</code></dt>
  <dd>key, cert, bad intermediate CA</dd>
  <dt><code>*-mismatchkey.rsa.pem</code></dt>
  <dd>key (does not match cert), cert, intermediate CA</dd>
</dl>
