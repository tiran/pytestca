#!/bin/bash
# Authors:
#   Christian Heimes <christian@python.org>
#
# Copyright (C) 2017 Christian Heimes

set -ex

if [ $# -lt 2 ]; then
    echo "$0 subcmd outfile"
    exit 2
fi

SUBCMD=$1
OUTFILE=$2
OUTDIR=$(dirname "$OUTFILE")
shift 2
mkdir -p "$OUTDIR"

case "$(basename $OUTFILE)" in
    *rsa*)
        ALGO=RSA
        ;;
    *ecc*)
        ALGO=ECC
        ;;
    *)
        ALGO=
        ;;
esac

function cafiles {
    mkdir -p "${1}/certs"
    if [ ! -f "${1}/index.db" ]; then
        touch "${1}/index.db"
        touch "${1}/index.db.attr"
        echo 01 > "${1}/ca.srl"
        echo 01 > "${1}/crl.srl"
    fi
}

case "$SUBCMD" in
    rsakey)
        openssl genrsa -out "$OUTFILE" "$1"
        ;;
    encrypt-rsakey)
        openssl rsa -out "$OUTFILE" -in "$1" -aes128 -passout "pass:$2"
        ;;
    ecckey)
        openssl ecparam -genkey -out "$OUTFILE" -name $1
        ;;
    encrypt-ecckey)
        openssl ec -out "$OUTFILE" -in "$1" -aes128 -passout "pass:$2"
        ;;
    csr)
        openssl req -batch -new -out "$OUTFILE" -key $1 -config <(sed s/\@ALGO\@/$ALGO/ $2)
        ;;
    sign-rootca)
        # ignore $3
        cafiles "$OUTDIR"
        openssl ca -batch -selfsign -out "$OUTFILE" -in $1 \
            -extensions ca_ext -config <(sed s/\@ALGO\@/$ALGO/ $2)
        ;;
    sign-ca)
        # ignore $3
        cafiles "$OUTDIR"
        openssl ca -batch -out "$OUTFILE" -in $1 \
            -extensions ca_ext -config <(sed s/\@ALGO\@/$ALGO/ $2)
        ;;
    sign-tlsserver)
        # ignore $3
        openssl ca -batch -out "$OUTFILE" -in $1 \
            -extensions tlsserver_ext -config <(sed s/\@ALGO\@/$ALGO/ $2)
        ;;
    sign-tlsclient)
        # ignore $3
        openssl ca -batch -out "$OUTFILE" -in $1 \
            -extensions tlsclient_ext -config <(sed s/\@ALGO\@/$ALGO/ $2)
        ;;
    revoke)
        openssl ca -batch -revoke "$OUTFILE" -config <(sed s/\@ALGO\@/$ALGO/ $1) \
            -crl_reason keyCompromise
        ;;
    crl)
        # ignore %1 (index.db)
        openssl ca -batch -gencrl -config <(sed s/\@ALGO\@/$ALGO/ $1) \
            | openssl crl -text -out "$OUTFILE"
        ;;
    capath)
        capath="$OUTFILE"
        rm -rf "${capath}"
        mkdir -p "${capath}"
        outfiles=()
        # copy certs/crls without most of the text header
        for name in $@; do
            out="${capath}/$(basename ${name})"
            outfiles+=("${out}")
            case ${name} in
                *.crt)
                    grep -E -o "Subject:.*" "${name}" > "${out}"
                    openssl x509 -in ${name} >> "${out}"
                    ;;
                *.crl)
                    grep -E -o "Issuer:.*" "${name}" > "${out}"
                    openssl crl -in ${name} >> "${out}"
                    ;;
                *)
                    echo "Unsupported ${out}"
                    exit 1
            esac
        done
        # requires OpenSSL 1.1.0+, use -compat to create OpenSSL 0.9.8 hashes
        openssl rehash "${capath}"
        # convert symlinks to actual files
        for linkname in $(find "${capath}" -type l); do
		    target=$(realpath "${linkname}")
		    rm "${linkname}"
		    cp "${target}" "${linkname}";
	    done
	    # remove non-hash files
        for name in ${outfiles[@]}; do
            rm "${name}"
        done
        ;;
    *)
        echo "Unsupported sub command $SUBCMD"
        exit 2
        ;;
esac
