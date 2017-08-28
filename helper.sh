#!/bin/bash
# Authors:
#   Christian Heimes <christian@python.org>
#
# Copyright (C) 2017 Christian Heimes

set -e

if [ $# -lt 2 ]; then
    echo "$0 subcmd outfile"
    exit 2
fi

SUBCMD=$1
OUTFILE=$2
OUTDIR=$(dirname "$OUTFILE")
shift 2
mkdir -p "$OUTDIR"

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
    key)
        openssl genrsa -out "$OUTFILE" 2048
        ;;
    csr)
        openssl req -batch -new -out "$OUTFILE" -key $1 -config $2
        ;;
    sign-rootca)
        # ignore $3
        cafiles "$OUTDIR"
        openssl ca -batch -selfsign -out "$OUTFILE" -in $1 \
            -extensions ca_ext -config $2
        ;;
    sign-ca)
        # ignore $3
        cafiles "$OUTDIR"
        openssl ca -batch -out "$OUTFILE" -in $1 \
            -extensions ca_ext -config $2
        ;;
    sign-tlsserver)
        # ignore $3
        openssl ca -batch -out "$OUTFILE" -in $1 \
            -extensions tlsserver_ext -config $2
        ;;
    sign-tlsclient)
        # ignore $3
        openssl ca -batch -out "$OUTFILE" -in $1 \
            -extensions tlsclient_ext -config $2
        ;;
    revoke)
        openssl ca -batch -revoke "$OUTFILE" -config $1 \
            -crl_reason keyCompromise
        ;;
    crl)
        # ignore %1 (index.db)
        openssl ca -batch -gencrl -config $1 | openssl crl -text -out "$OUTFILE"
        ;;
    *)
        echo "Unsupported sub command $SUBCMD"
        exit 2
        ;;
esac
