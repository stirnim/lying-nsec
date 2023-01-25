#!/bin/bash

# defaults
nameserver="1.1.1.1:53"
# zdns uses 1000 threads by default
# reducing the number of threads to avoid SERVFAIL and TIMEOUT responses
threads="50"

while getopts "hvn:t:" flag; do
    case "${flag}" in
        n)
            nameserver="$OPTARG"
            ;;
        h)
            echo "Usage: $0 [-n <name-server>] [-t threads] <prefix>"
            echo "     <prefix>          prefix name for input- and output files e.g. XXX-domainlist.txt"
            echo ""
            echo " optional arguments:"
            echo "     -n <name-server>  list of name servers to use. can be passed as comma-delimited string. optional port can be specified, default $nameserver"
            echo "     -t <threads>      set the number of zdns threads, default $threads"
            exit 0
            ;;
        \?) echo "Invalid Option: -$OPTARG" 1>&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

prefixname="$1"
prefix="${prefixname}-"

if [ -z "${prefixname}" ]; then
    echo "Please provide a prefix" 1>&2; exit 1
fi

domainlist="${prefix}domainlist.txt"

if [ ! -r "${domainlist}" ]; then
    echo "${domainlist} not found or not readable" 1>&2; exit 1
fi

echo "Start measurement at `date`"

# count signed domains
count=$(wc -l ${domainlist} | awk '{print $1}')
echo "Found $count signed domains"

# first ZDNS run to check if www hostname exists
go/bin/zdns A --threads $threads --name-servers $nameserver --prefix www. --input-file ${domainlist} --output-file ${prefix}www.jsonlines
cat ${prefix}www.jsonlines | jq -r 'select(.status == "NOERROR") | .name' > ${prefix}www-domainlist.txt

# count signed domains with www hostname
count=$(wc -l ${prefix}www-domainlist.txt | awk '{print $1}')
echo "Found $count signed domains with www hostname"

# second ZDNS run to trigger NODATA response
go/bin/zdns NULL --dnssec --threads $threads --name-servers $nameserver --input-file ${prefix}www-domainlist.txt --output-file ${prefix}nodata.jsonlines

echo "Finish measurement at `date`"

# analyze-result checks for minimal covering NSEC, NSEC3 chains proofing
# the non-existence of other names in the zone
./analyze-result.py -o ${prefix}lying.jsonlines ${prefix}nodata.jsonlines
