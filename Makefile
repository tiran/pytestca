# Authors:
#   Christian Heimes <christian@python.org>
#
# Copyright (C) 2017 Christian Heimes

CERTS=
CRLS=

OUT=out
TMP=tmp

CSR=$(TMP)/csr
CADIR=$(TMP)
CAPATH=$(OUT)/capath

.PHONY: all
all: certs crls capath test

.PHONY: clean
clean:
	rm -rf $(OUT) $(TMP)

# OpenSSL's CA database is not concurrency-safe.
.NOTPARALLEL:

$(OUT):
	mkdir -p $@

$(CADIR):
	mkdir -p $@

# ****************************************************************
.PRECIOUS: $(CADIR)/%/ca.key
$(CADIR)/%/ca.key: helper.sh $(CADIR)
	./helper.sh key $@

$(CADIR)/%/ca.csr: $(CADIR)/%/ca.key conf/%.conf
	./helper.sh csr $@ $^

# ********************************
ROOTCERT=$(CADIR)/root-ca/ca.crt
CERTS+=$(OUT)/root-ca.crt $(OUT)/root-ca-noserver.crt
CRLS+=$(OUT)/root-ca.crl

$(ROOTCERT): $(CADIR)/root-ca/ca.csr conf/root-ca.conf
	./helper.sh sign-rootca $@ $^

$(CADIR)/root-ca/index.db: $(ROOTCERT)

$(OUT)/root-ca.crl: conf/root-ca.conf $(CADIR)/root-ca/index.db
	./helper.sh crl $@ $<

$(OUT)/root-ca.crt: $(ROOTCERT) $(OUT)
	cp $< $@

$(OUT)/root-ca-noserver.crt: $(ROOTCERT) $(OUT)
	openssl x509 -in $< -out $@ -text -trustout -addreject serverAuth -addtrust clientAuth

# ********************************
INTERMEDIATECERT=$(CADIR)/intermediate-ca/ca.crt
CERTS+=$(OUT)/intermediate-ca.crt
CRLS+=$(OUT)/intermediate-ca.crl

$(INTERMEDIATECERT): $(CADIR)/intermediate-ca/ca.csr conf/root-ca.conf $(ROOTCERT)
	./helper.sh sign-ca $@ $^

$(CADIR)/intermediate-ca/index.db: $(INTERMEDIATECERT)

$(OUT)/intermediate-ca.crl: conf/intermediate-ca.conf $(CADIR)/intermediate-ca/index.db
	./helper.sh crl $@ $<

$(OUT)/intermediate-ca.crt: $(INTERMEDIATECERT) $(OUT)
	cp $< $@

# ****************************************************************
.PRECIOUS: $(OUT)/%.key
$(OUT)/%.key: helper.sh $(OUT)
	./helper.sh key $@

$(CSR)/%.csr: $(OUT)/%.key conf/%.conf
	./helper.sh csr $@ $^

$(OUT)/%-chain.pem: $(OUT)/%.crt $(INTERMEDIATECERT)
	cat $^ > $@

$(OUT)/%-combined.pem: $(OUT)/%.key $(OUT)/%.crt $(INTERMEDIATECERT)
	cat $^ > $@

# ********************************
CERTS+=$(OUT)/allsans-chain.pem $(OUT)/allsans-combined.pem

$(OUT)/allsans.crt: $(CSR)/allsans.csr conf/intermediate-ca.conf $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^

# ********************************
CERTS+=$(OUT)/revoked-chain.pem $(OUT)/revoked-combined.pem

$(OUT)/revoked.crt: $(CSR)/revoked.csr conf/intermediate-ca.conf $(INTERMEDIATECERT)
	./helper.sh sign-tlsserver $@ $^
	./helper.sh revoke $@ conf/intermediate-ca.conf

# ********************************
CERTS+=$(OUT)/clientauth-chain.pem $(OUT)/clientauth-combined.pem

$(OUT)/clientauth.crt: $(CSR)/clientauth.csr conf/intermediate-ca.conf $(INTERMEDIATECERT)
	./helper.sh sign-tlsclient $@ $^

# ********************************
.PHONY: test
test: $(CERTS) capath
	@openssl verify -purpose sslserver \
		-CAfile $(ROOTCERT) \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/allsans.crt
	@openssl verify -purpose sslclient \
		-CAfile $(ROOTCERT) \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/allsans.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslserver \
		-CApath $(CAPATH) -crl_check_all \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/allsans.crt
	@openssl verify -purpose sslserver \
		-CAfile $(OUT)/root-ca-noserver.crt \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/allsans.crt && exit 1 || echo "... EXPECTED"

	@openssl verify -purpose sslserver \
		-CAfile $(ROOTCERT) \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/revoked.crt
	@openssl verify -purpose sslserver -CApath $(CAPATH) -crl_check_all \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/revoked.crt && exit 1 || echo "... EXPECTED"

	@openssl verify -purpose sslclient \
		-CAfile $(ROOTCERT) \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/clientauth.crt
	@openssl verify -purpose sslserver \
		-CAfile $(ROOTCERT) \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/clientauth.crt && exit 1 || echo "... EXPECTED"
	@openssl verify -purpose sslclient \
		-CApath $(CAPATH) -crl_check_all \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/clientauth.crt
	@openssl verify -purpose sslclient \
		-CAfile $(OUT)/root-ca-noserver.crt \
		-untrusted $(INTERMEDIATECERT) \
		$(OUT)/clientauth.crt

	@echo "All tests passed"

# ********************************
.PHONY: capath
capath: $(ROOTCERT) $(CRLS)
	rm -f $(CAPATH)/*
	mkdir -p $(CAPATH)
	cp -t $(CAPATH) $^
	# requires OpenSSL 1.1.0+
	openssl rehash -compat $(CAPATH)
	for linkname in $$(find $(CAPATH) -type l); do \
		target=$$(realpath "$$linkname"); \
		rm "$$linkname";  \
		cp "$$target" "$$linkname"; \
	done
	rm $(foreach file,$^,$(CAPATH)/$(notdir $(file)))

.PHONY: certs
certs: $(CERTS)

.PHONY: crls
crls: $(CRLS)
