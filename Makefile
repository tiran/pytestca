# Authors:
#   Christian Heimes <christian@python.org>
#
# Copyright (C) 2017 Christian Heimes

# parameters
RSABITS=2048
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

.PRECIOUS: $(CADIR)/%/ca.key
$(CADIR)/%/ca.key: helper.sh
	./helper.sh key $@ $(RSABITS)

$(CADIR)/%/ca.csr: $(CADIR)/%/ca.key $(CADIR)/%/ca.conf
	./helper.sh csr $@ $^

# CA cert with no extra text except subject
$(CADIR)/%/ca-notext.crt: $(CADIR)/%/ca.crt
	grep -E -o "Subject:.*" $< > $@
	openssl x509 -in $< >> $@

# ********************************
# Root CA cert and copy as trusted cert w/o serverAuth
ROOTCERT=$(CADIR)/$(ROOTCA)/ca.crt
ROOTCONF=$(CADIR)/$(ROOTCA)/ca.conf

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
INTERMEDIATECERT=$(CADIR)/$(INTERMEDIATECA)/ca.crt
INTERMEDIATECERTNOTEXT=$(CADIR)/$(INTERMEDIATECA)/ca-notext.crt

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
	./helper.sh key $@ $(RSABITS)

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
# cert rules
.PRECIOUS: $(KEYDIR)/%.key
$(KEYDIR)/%.key: helper.sh
	./helper.sh key $@ $(RSABITS)

$(KEYDIR)/%.passwd.key: $(KEYDIR)/%.key
	./helper.sh encrypt-key $@ $< $(PASSWORD)

$(CSRDIR)/%.csr: $(KEYDIR)/%.key conf/%.conf
	./helper.sh csr $@ $^

$(OUT)/%.key: $(KEYDIR)/%.key | $(OUT)
	cp $< $@

$(OUT)/%.passwd.key: $(KEYDIR)/%.passwd.key | $(OUT)
	cp $< $@

$(OUT)/%.crt: $(CERTDIR)/%.crt | $(OUT)
	cp $< $@

$(OUT)/%-chain.pem: $(CERTDIR)/%.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-combined.pem: $(KEYDIR)/%.key $(CERTDIR)/%.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-combined.passwd.pem: $(KEYDIR)/%.passwd.key $(CERTDIR)/%.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-badcert.pem: $(KEYDIR)/%.key $(CERTDIR)/%.crt $(BADCERT) | $(OUT)
	cat $^ > $@

$(OUT)/%-badkey.pem: $(BADKEY) $(CERTDIR)/%.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

$(OUT)/%-mismatchkey.pem: $(MISMATCHKEY) $(CERTDIR)/%.crt $(INTERMEDIATECERTNOTEXT) | $(OUT)
	cat $^ > $@

# ********************************
CERTS+=$(OUT)/allsans.crt $(OUT)/allsans.key
CERTS+=$(OUT)/allsans-chain.pem
CERTS+=$(OUT)/allsans-combined.pem
CERTS+=$(OUT)/allsans-combined.passwd.pem
CERTS+=$(OUT)/allsans-badcert.pem
CERTS+=$(OUT)/allsans-badkey.pem
CERTS+=$(OUT)/allsans-mismatchkey.pem

$(CERTDIR)/allsans.crt: $(CSRDIR)/allsans.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/revoked-combined.pem

$(CERTDIR)/revoked.crt: $(CSRDIR)/revoked.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^
	./helper.sh revoke $@ $(INTERMEDIATECONF)

# ********************************
CERTS+=$(OUT)/client-combined.pem

$(CERTDIR)/client.crt: $(CSRDIR)/client.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsclient $@ $^

# ********************************
CERTS+=$(OUT)/localhost-combined.pem

$(CERTDIR)/localhost.crt: $(CSRDIR)/localhost.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/localip-combined.pem

$(CERTDIR)/localip.crt: $(CSRDIR)/localip.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/localhost-cnonly-combined.pem

$(CERTDIR)/localhost-cnonly.crt: $(CSRDIR)/localhost-cnonly.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/idna2003-combined.pem

$(CERTDIR)/idna2003.crt: $(CSRDIR)/idna2003.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/idna2008-combined.pem

$(CERTDIR)/idna2008.crt: $(CSRDIR)/idna2008.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/wildcards-combined.pem

$(CERTDIR)/wildcards.crt: $(CSRDIR)/wildcards.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
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
		$(CERTDIR)/allsans.crt
	@openssl verify -purpose sslclient 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslserver 		\
		-CApath $(CAPATH) -crl_check_all	\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.crt
	@openssl verify -purpose sslserver 		\
		-CAfile $(OUT)/$(ROOTCA)-untrustedserver.crt \
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/allsans.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslserver 		\
		-CApath $(CAPATH) -crl_check_all	\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname wronghost			\
		$(CERTDIR)/allsans.crt && exit 1 || echo "... EXPECTED"

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/revoked.crt
	@openssl verify -purpose sslserver 		\
		-CApath $(CAPATH) -crl_check_all 	\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/revoked.crt && exit 1 || echo "... EXPECTED"

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/localhost.crt

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_hostname localhost			\
		$(CERTDIR)/localhost-cnonly.crt

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_ip 127.0.0.1				\
		$(CERTDIR)/localip.crt
	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_ip ::1						\
		$(CERTDIR)/localip.crt

	@openssl verify -purpose sslclient 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.crt
	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT)					\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslclient 		\
		-CApath $(CAPATH) -crl_check_all 	\
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.crt
	@openssl verify -purpose sslclient 		\
		-CAfile $(OUT)/$(ROOTCA)-untrustedserver.crt \
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.crt

.PHONY: pythontests
pythontests: certs capath
	python3 testca.py

.PHONY: certs
certs: $(CERTS)

.PHONY: crls
crls: $(CRLS)
