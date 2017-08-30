# Authors:
#   Christian Heimes <christian@python.org>
#
# Copyright (C) 2017 Christian Heimes

RSABITS=2048
PASSWORD=somepass

CERTS=
CRLS=

OUT=out
CAPATH=$(OUT)/capath

TMP=tmp
CSRDIR=$(TMP)/csr
KEYDIR=$(TMP)/key
CERTDIR=$(TMP)/cert
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

$(CADIR):
	mkdir -p $@

# ****************************************************************
.PRECIOUS: conf/%.conf
$(CADIR)/%-ca.conf: conf/template/%-ca.conf conf/template/ca.conf | $(CADIR)
	echo -e "# WARNING: auto-generated file. DO NOT EDIT\n" > $@
	cat $^ >> $@

.PRECIOUS: $(CADIR)/%/ca.key
$(CADIR)/%/ca.key: helper.sh
	./helper.sh key $@ $(RSABITS)

$(CADIR)/%/ca.csr: $(CADIR)/%/ca.key $(CADIR)/%.conf
	./helper.sh csr $@ $^

# ********************************
# Root CA cert and copy as trusted cert w/o serverAuth
ROOTCERT=$(CADIR)/root-ca/ca.crt
ROOTCONF=$(CADIR)/root-ca.conf

$(ROOTCERT): $(CADIR)/root-ca/ca.csr $(ROOTCONF)
	./helper.sh sign-rootca $@ $^

$(CADIR)/root-ca/index.db: $(ROOTCERT)

CRLS+=$(OUT)/root-ca.crl
$(OUT)/root-ca.crl: $(ROOTCONF) $(CADIR)/root-ca/index.db | $(OUT)
	./helper.sh crl $@ $<

CERTS+=$(OUT)/root-ca.crt
$(OUT)/root-ca.crt: $(ROOTCERT) | $(OUT)
	cp $< $@

CERTS+=$(OUT)/root-ca-untrustedserver.crt
$(OUT)/root-ca-untrustedserver.crt: $(ROOTCERT) | $(OUT)
	openssl x509 -in $< -out $@ -text -trustout -addreject serverAuth -addtrust clientAuth

# ********************************
# intermediate CA cert
INTERMEDIATECERT=$(CADIR)/intermediate-ca/ca.crt
INTERMEDIATECONF=$(CADIR)/intermediate-ca.conf

$(INTERMEDIATECERT): $(CADIR)/intermediate-ca/ca.csr $(ROOTCONF) $(ROOTCERT)
	./helper.sh sign-ca $@ $^

$(CADIR)/intermediate-ca/index.db: $(INTERMEDIATECERT)

CRLS+=$(OUT)/intermediate-ca.crl
$(OUT)/intermediate-ca.crl: $(INTERMEDIATECONF) $(CADIR)/intermediate-ca/index.db | $(OUT)
	mkdir -p $(OUT)
	./helper.sh crl $@ $<

CERTS+=$(OUT)/intermediate-ca.crt
$(OUT)/intermediate-ca.crt: $(INTERMEDIATECERT) | $(OUT)
	cp $< $@

# ****************************************************************
.PRECIOUS: $(KEYDIR)/%.key
$(KEYDIR)/%.key: helper.sh
	./helper.sh key $@ $(RSABITS)

$(CSRDIR)/%.csr: $(KEYDIR)/%.key conf/%.conf
	./helper.sh csr $@ $^

$(OUT)/%.key: $(KEYDIR)/%.key | $(OUT)
	cp $< $@

$(OUT)/%.passwd.key: $(KEYDIR)/%.key | $(OUT)
	./helper.sh encrypt-key $@ $< $(PASSWORD)

$(OUT)/%.crt: $(CERTDIR)/%.crt | $(OUT)
	cp $< $@

$(OUT)/%-chain.pem: $(KEYDIR)/%.key $(INTERMEDIATECERT) | $(OUT)
	cat $^ > $@

$(OUT)/%-combined.pem: $(KEYDIR)/%.key $(CERTDIR)/%.crt $(INTERMEDIATECERT) | $(OUT)
	cat $^ > $@

$(OUT)/%-combined.passwd.pem: $(OUT)/%.passwd.key $(CERTDIR)/%.crt $(INTERMEDIATECERT) | $(OUT)
	cat $^ > $@

# ********************************
CERTS+=$(OUT)/allsans.crt $(OUT)/allsans.key
CERTS+=$(OUT)/allsans-chain.pem
CERTS+=$(OUT)/allsans-combined.pem $(OUT)/allsans-combined.passwd.pem

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
CERTS+=$(OUT)/localhost-nocn-combined.pem

$(CERTDIR)/localhost-nocn.crt: $(CSRDIR)/localhost-nocn.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/localip-nocn-combined.pem

$(CERTDIR)/localip-nocn.crt: $(CSRDIR)/localip-nocn.csr $(INTERMEDIATECONF) $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
.PHONY: capath
capath: $(ROOTCERT) $(CRLS)
	rm -f $(CAPATH)/*
	mkdir -p $(CAPATH)
	cp -t $(CAPATH) $^
	# requires OpenSSL 1.1.0+, use -compat to create OpenSSL 0.9.8 hashes
	openssl rehash $(CAPATH)
	for linkname in $$(find $(CAPATH) -type l); do \
		target=$$(realpath "$$linkname"); \
		rm "$$linkname";  \
		cp "$$target" "$$linkname"; \
	done
	rm $(foreach file,$^,$(CAPATH)/$(notdir $(file)))

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
		-CAfile $(OUT)/root-ca-untrustedserver.crt \
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
		$(CERTDIR)/localhost-nocn.crt

	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_ip 127.0.0.1				\
		$(CERTDIR)/localip-nocn.crt
	@openssl verify -purpose sslserver 		\
		-CAfile $(ROOTCERT) 				\
		-untrusted $(INTERMEDIATECERT) 		\
		-verify_ip ::1						\
		$(CERTDIR)/localip-nocn.crt

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
		-CAfile $(OUT)/root-ca-untrustedserver.crt \
		-untrusted $(INTERMEDIATECERT) 		\
		$(CERTDIR)/client.crt

.PHONY: pythontests
pythontests: certs capath
	python3 testca.py

.PHONY: certs
certs: $(CERTS)

.PHONY: crls
crls: $(CRLS)
