# Authors:
#   Christian Heimes <christian@python.org>
#
# Copyright (C) 2017 Christian Heimes

# parameters
RSABITS=2048
ECDSA_CURVE=prime256v1
PASSWORD=somepass
ROOTCA=pyrootca
INTERMEDIATECA=pysubca

# accumulators for certs, keys and CRLs
CERTS=
CRLS=

# output directory and capath
OUT=out
CAPATH=$(OUT)/capath

# temporary directories
TMP=tmp
CSRDIR=$(TMP)/csrs
KEYDIR=$(TMP)/keys
CERTDIR=$(TMP)/certs
CADIR=$(TMP)

# OpenSSL's CA database is not concurrency-safe.
.NOTPARALLEL:

.PHONY: all
all: certs crls capath test
	@echo
	@echo "Python Test CA certs"
	@echo "--------------------"
	@find $(OUT) -type f | sort

.PHONY: clean
clean:
	rm -rf $(OUT) $(TMP)

.PHONY: test
test: pythontests openssltests
	@echo "All tests passed"

$(OUT):
	mkdir -p $@

# ****************************************************************
.PRECIOUS: $(CADIR)/%/ca.conf
$(CADIR)/%/ca.conf: conf/template/%.conf conf/template/ca.conf
	mkdir -p $(dir $@)
	echo -e "# WARNING: auto-generated file. DO NOT EDIT\n" > $@
	cat $^ >> $@

$(CADIR)/%/ca.csr: $(CADIR)/%/ca.key $(CADIR)/%/ca.conf
	./helper.sh csr $@ $^

# CA cert with no extra text except subject
$(CADIR)/%/ca-notext.crt: $(CADIR)/%/ca.crt
	grep -E -o "Subject:.*" $< > $@
	openssl x509 -in $< >> $@

# ********************************
# Root CA cert and copy as trusted cert w/o serverAuth
ROOTCONF=$(CADIR)/$(ROOTCA)/ca.conf
ROOTKEY=$(CADIR)/$(ROOTCA)/ca.key
ROOTCERT=$(CADIR)/$(ROOTCA)/ca.crt

.PRECIOUS: $(ROOTKEY)
$(ROOTKEY): helper.sh
	./helper.sh rsakey $@ $(RSABITS)

$(ROOTCERT): $(CADIR)/$(ROOTCA)/ca.csr $(ROOTCONF)
	./helper.sh sign-rootca $@ $^

$(CADIR)/$(ROOTCA)/index.db: $(ROOTCERT)

CRLS+=$(OUT)/$(ROOTCA).crl
$(OUT)/$(ROOTCA).crl: $(ROOTCONF) $(CADIR)/$(ROOTCA)/index.db | $(OUT)
	./helper.sh crl $@ $<

CERTS+=$(OUT)/$(ROOTCA).crt
$(OUT)/$(ROOTCA).crt: $(ROOTCERT) | $(OUT)
	cp $< $@

CERTS+=$(OUT)/$(ROOTCA)-untrustedserver.crt
$(OUT)/$(ROOTCA)-untrustedserver.crt: $(ROOTCERT) | $(OUT)
	openssl x509 -in $< -out $@ -text -trustout -addreject serverAuth -addtrust clientAuth

# ********************************
# intermediate CA cert
INTERMEDIATECONF=$(CADIR)/$(INTERMEDIATECA)/ca.conf
INTERMEDIATEKEY=$(CADIR)/$(INTERMEDIATECA)/ca.key
INTERMEDIATECERT=$(CADIR)/$(INTERMEDIATECA)/ca.crt
INTERMEDIATECERTNOTEXT=$(CADIR)/$(INTERMEDIATECA)/ca-notext.crt

.PRECIOUS: $(INTERMEDIATEKEY)
$(INTERMEDIATEKEY): helper.sh
	./helper.sh rsakey $@ $(RSABITS)

$(INTERMEDIATECERT): $(CADIR)/$(INTERMEDIATECA)/ca.csr $(ROOTCONF) $(ROOTCERT)
	./helper.sh sign-ca $@ $^

$(CADIR)/$(INTERMEDIATECA)/index.db: $(INTERMEDIATECERT)

CRLS+=$(OUT)/$(INTERMEDIATECA).crl
$(OUT)/$(INTERMEDIATECA).crl: $(INTERMEDIATECONF) $(CADIR)/$(INTERMEDIATECA)/index.db | $(OUT)
	mkdir -p $(OUT)
	./helper.sh crl $@ $<

CERTS+=$(OUT)/$(INTERMEDIATECA).crt
$(OUT)/$(INTERMEDIATECA).crt: $(INTERMEDIATECERT) | $(OUT)
	cp $< $@

# ****************************************************************
# extra stuff
CACERTORG=extras/cacert.crt
BADKEY=extras/badkey.key
BADCERT=extras/badcert.crt
MISMATCHKEY=$(KEYDIR)/mismatch.key

CERTS+=$(OUT)/cacert.crt
$(OUT)/cacert.crt: $(CACERTORG)
	cp $< $@

.PRECIOUS: $(MISMATCHKEY)
$(MISMATCHKEY): helper.sh
	./helper.sh rsakey $@ $(RSABITS)

# ****************************************************************
# Diffie-Hellmann parameters
DHPARAM512=$(OUT)/dhparam512.pem
DHPARAM1024=$(OUT)/dhparam1024.pem
DHPARAM2048=$(OUT)/dhparam2048.pem
DHPARAMS=$(DHPARAM512) $(DHPARAM1024) $(DHPARAM2048)

CERTS+=$(DHPARAMS)

.PHONY: dhparams
dhparams: $(DHPARAMS)

$(OUT)/dhparam%.pem: extras/dhparam%.pem
	cp $< $@

# files are pre-cached because it takes rather long to generate them.
extras/dhparam%.pem:
	openssl dhparam -out $@ $*

# ****************************************************************
# cert rules (RSA)
.PRECIOUS: $(KEYDIR)/%.rsa.key
$(KEYDIR)/%.rsa.key: helper.sh
	./helper.sh rsakey $@ $(RSABITS)

$(KEYDIR)/%.passwd.rsa.key: $(KEYDIR)/%.rsa.key
	./helper.sh encrypt-rsakey $@ $< $(PASSWORD)

$(CSRDIR)/%.rsa.csr: $(KEYDIR)/%.rsa.key conf/%.conf
	./helper.sh csr $@ $^

$(OUT)/%.rsa.key: $(KEYDIR)/%.rsa.key | $(OUT)
	cp $< $@

$(OUT)/%.passwd.rsa.key: $(KEYDIR)/%.passwd.rsa.key | $(OUT)
	cp $< $@

$(OUT)/%.rsa.crt: $(CERTDIR)/%.rsa.crt | $(OUT)
	cp $< $@

$(OUT)/%-chain.rsa.pem: $(CERTDIR)/%.rsa.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-combined.rsa.pem: $(KEYDIR)/%.rsa.key $(CERTDIR)/%.rsa.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-combined.passwd.rsa.pem: $(KEYDIR)/%.passwd.rsa.key $(CERTDIR)/%.rsa.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

# cert rules (ECDSA)
.PRECIOUS: $(KEYDIR)/%.ecc.key
$(KEYDIR)/%.ecc.key: helper.sh
	./helper.sh ecckey $@ $(ECDSA_CURVE)

$(KEYDIR)/%.passwd.ecc.key: $(KEYDIR)/%.ecc.key
	./helper.sh encrypt-ecckey $@ $< $(PASSWORD)

$(CSRDIR)/%.ecc.csr: $(KEYDIR)/%.ecc.key conf/%.conf
	./helper.sh csr $@ $^

$(OUT)/%.ecc.key: $(KEYDIR)/%.ecc.key | $(OUT)
	cp $< $@

$(OUT)/%.passwd.ecc.key: $(KEYDIR)/%.passwd.ecc.key | $(OUT)
	cp $< $@

$(OUT)/%.ecc.crt: $(CERTDIR)/%.ecc.crt | $(OUT)
	cp $< $@

$(OUT)/%-combined.ecc.pem: $(KEYDIR)/%.ecc.key $(CERTDIR)/%.ecc.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-combined.passwd.ecc.pem: $(KEYDIR)/%.passwd.ecc.key $(CERTDIR)/%.ecc.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

# cert rules (bad certs)
$(OUT)/%-badcert.rsa.pem: $(KEYDIR)/%.rsa.key $(CERTDIR)/%.rsa.crt $(BADCERT) | $(OUT)
	cat $^ > $@

$(OUT)/%-badkey.rsa.pem: $(BADKEY) $(CERTDIR)/%.rsa.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-mismatchkey.rsa.pem: $(MISMATCHKEY) $(CERTDIR)/%.rsa.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

# ********************************
CERTS+=$(OUT)/allsans.rsa.crt $(OUT)/allsans.rsa.key
CERTS+=$(OUT)/allsans-chain.rsa.pem
CERTS+=$(OUT)/allsans-combined.rsa.pem
CERTS+=$(OUT)/allsans-combined.passwd.rsa.pem
CERTS+=$(OUT)/allsans-badcert.rsa.pem
CERTS+=$(OUT)/allsans-badkey.rsa.pem
CERTS+=$(OUT)/allsans-mismatchkey.rsa.pem

CERTS+=$(OUT)/allsans.ecc.crt $(OUT)/allsans.ecc.key
CERTS+=$(OUT)/allsans-combined.ecc.pem
CERTS+=$(OUT)/allsans-combined.passwd.ecc.pem

$(CERTDIR)/allsans.rsa.crt: $(CSRDIR)/allsans.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

$(CERTDIR)/allsans.ecc.crt: $(CSRDIR)/allsans.ecc.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/revoked-combined.rsa.pem

$(CERTDIR)/revoked.rsa.crt: $(CSRDIR)/revoked.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^
	./helper.sh revoke $@ $(INTERMEDIATECONF)

# ********************************
CERTS+=$(OUT)/client-combined.rsa.pem

$(CERTDIR)/client.rsa.crt: $(CSRDIR)/client.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsclient $@ $^

# ********************************
CERTS+=$(OUT)/localhost-combined.rsa.pem

$(CERTDIR)/localhost.rsa.crt: $(CSRDIR)/localhost.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/localip-combined.rsa.pem

$(CERTDIR)/localip.rsa.crt: $(CSRDIR)/localip.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/localhost-cnonly-combined.rsa.pem

$(CERTDIR)/localhost-cnonly.rsa.crt: $(CSRDIR)/localhost-cnonly.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/idna2003-combined.rsa.pem

$(CERTDIR)/idna2003.rsa.crt: $(CSRDIR)/idna2003.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/idna2008-combined.rsa.pem

$(CERTDIR)/idna2008.rsa.crt: $(CSRDIR)/idna2008.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/wildcards-combined.rsa.pem

$(CERTDIR)/wildcards.rsa.crt: $(CSRDIR)/wildcards.rsa.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
.PHONY: capath
capath: $(OUT)/$(ROOTCA).crt $(CACERTORG) $(CRLS)
	./helper.sh capath $(CAPATH) $^

# ********************************
.PHONY: openssltests
openssltests: certs capath
	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.rsa.crt
	@openssl verify -purpose sslclient 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.rsa.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslserver 		\
		-CApath $(CAPATH) -crl_check_all	\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.rsa.crt
	@openssl verify -purpose sslserver 		\
		-CAfile $(OUT)/$(ROOTCA)-untrustedserver.crt \
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.rsa.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslserver 		\
		-CApath $(CAPATH) -crl_check_all	\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname wronghost			\
		$(CERTDIR)/allsans.rsa.crt && exit 1 || echo "... EXPECTED"

	@openssl verify -purpose sslserver 		\
		-CApath $(CAPATH) -crl_check_all	\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.ecc.crt

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/revoked.rsa.crt
	@openssl verify -purpose sslserver 		\
		-CApath $(CAPATH) -crl_check_all 	\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/revoked.rsa.crt && exit 1 || echo "... EXPECTED"

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/localhost.rsa.crt

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/localhost-cnonly.rsa.crt

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_ip 127.0.0.1				\
		$(CERTDIR)/localip.rsa.crt
	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_ip ::1						\
		$(CERTDIR)/localip.rsa.crt

	@openssl verify -purpose sslclient 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.rsa.crt
	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT)					\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.rsa.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslclient 		\
		-CApath $(CAPATH) -crl_check_all 	\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.rsa.crt
	@openssl verify -purpose sslclient 		\
		-CAfile $(OUT)/$(ROOTCA)-untrustedserver.crt \
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.rsa.crt

.PHONY: pythontests
pythontests: certs capath
	python3 testca.py

.PHONY: certs
certs: $(CERTS)

.PHONY: crls
crls: $(CRLS)
