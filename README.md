# New CA for Python tests

## CA certs and CRLs

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
allsans-badcert.pem
allsans-badkey.pem
allsans-chain.pem
allsans-combined.passwd.pem
allsans-combined.pem
allsans.crt
allsans.key
allsans-mismatchkey.pem
client-combined.pem
idna2003-combined.pem
idna2008-combined.pem
localhost-cnonly-combined.pem
localhost-combined.pem
localip-combined.pem
revoked-combined.pem
wildcards-combined.pem
```

## DH params

```
dhparam512.pem
dhparam1024.pem
dhparam2048.pem
```

## suffixes

<dl>
  <dt><code>*.crt</code></dt>
  <dd>single X.509 cert (PEM encoded)</dd>
  <dt><code>*.-untrustedserver.crt</code></dt>
  <dd>Trusted X.509 root certificate with <code>-addreject serverAuth</code></dd>
  <dt><code>*.key</code></dt>
  <dd>private key (PEM encoded)</dd>
  <dt><code>*.passwd.key</code></dt>
  <dd>encrypted private key (PEM encoded), password: <code>somepass</code></dd>
  <dt><code>*.crl</code></dt>
  <dd>Certificate Revocation List (PEM encoded)</dd>
  <dt><code>*-chain.pem</code></dt>
  <dd>cert, intermediate CA</dd>
  <dt><code>*-combined.pem</code></dt>
  <dd>key, cert, intermediate CA</dd>
  <dt><code>*-combined.passwd.pem</code></dt>
  <dd>encrypted key, cert, intermediate CA</dd>
  <dt><code>*-badcert.pem</code></dt>
  <dd>key, cert, bad intermediate CA</dd>
  <dt><code>*-badkey.pem</code></dt>
  <dd>bad key, cert, intermediate CA</dd>
  <dt><code>*-badcert.pem</code></dt>
  <dd>key, cert, bad intermediate CA</dd>
  <dt><code>*-mismatchkey.pem</code></dt>
  <dd>key (does not match cert), cert, intermediate CA</dd>

</dl>
