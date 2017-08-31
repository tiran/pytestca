# New CA for Python tests

## CA certs and CRLs

```
pyrootca.crl
pyrootca.crt
pyrootca-untrustedserver.crt
pysubca.crl
pysubca.crt
```

Root CA and all CRLs are also available as ``capath`` directory.

```
out/capath/5be189af.r0
out/capath/4c69e26e.r0
out/capath/4c69e26e.0
```

## end entity certs

```
allsans-chain.pem
allsans-combined.passwd.pem
allsans-combined.pem
allsans.crt
allsans.key
client-combined.pem
idna2003-combined.pem
idna2008-combined.pem
localhost-cnonly-combined.pem
localhost-combined.pem
localip-combined.pem
revoked-combined.pem
wildcards-combined.pem
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
</dl>
