#!/bin/bash

# defaults
nameserver="1.1.1.1:53"
# zdns uses 1000 threads by default, this causes many servfails or timeouts for me.
threads="256"

while getopts "hvn:t:" flag; do
    case "${flag}" in
        n)
            nameserver="$OPTARG"
            ;;
        t)
            threads="$OPTARG"
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

# check domains with www prefix and trigger a NODATA response
go/bin/zdns NULL --dnssec --threads $threads --name-servers $nameserver --prefix www. --input-file ${domainlist} --output-file ${prefix}nodata.jsonlines

echo "Finish measurement at `date`"

./analyze-result.py -o ${prefix}lying.jsonlines ${prefix}nodata.jsonlines
