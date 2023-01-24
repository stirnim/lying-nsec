#!/bin/bash

DIR="go"

if [ -d "${DIR}" ]; then
    echo "Subdirectory ${DIR} already exists. Aborting."
    exit 1
fi

curdir=$(pwd)
export GOPATH="$curdir/${DIR}"

mkdir -p "$curdir/${DIR}/bin/"
mkdir -p "$curdir/${DIR}/src/"

cd "$curdir/${DIR}/src/"
git clone https://github.com/zmap/zdns
cd zdns
go build

cp zdns "$curdir/${DIR}/bin/"
cd $curdir

echo ""
echo "Testing zdns: echo switch.ch | ${DIR}/bin/zdns --dnssec SOA"
echo "switch.ch" | ${DIR}/bin/zdns --dnssec SOA
