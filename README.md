Lying NSEC, NSEC3
=================

This scripts detect domain names with a NSEC or NSEC3 record denying the existence
of the www hostname but where it exists. The NSEC or NSEC3 records have a valid RRSIG.

Note: https://dnsviz.net/ does not identify this lying NSEC, NSEC3 records yet.
See issue https://github.com/dnsviz/dnsviz/issues/114.

Example using `dig`:

```bash
dig @8.8.8.8 www.ralexm.li NULL +dnssec
...
;; ANSWER SECTION:
www.ralexm.li.		21600	IN	CNAME	ralexm.li.
www.ralexm.li.		21600	IN	RRSIG	CNAME 13 3 86400 20230202000000 20230112000000 35571 ralexm.li. rR8o/Tnu9jEqz51uvE9/HmuSynn6b+zgDhxCndlUUrOPogWb+05gKKS/ 2mtKLBadA+iAJhNxHoJrfQnDgwGdtw==

;; AUTHORITY SECTION:
ralexm.li.		1500	IN	SOA	ns1.ralexm.cloud. hostmaster.ralexm.cloud. 2022112103 10800 3600 604800 3600
ralexm.li.		1500	IN	RRSIG	SOA 13 2 1500 20230202000000 20230112000000 35571 ralexm.li. dUeu9dRtyR7eTwsrFStSADO2YiiyluBuZ8ROUiUHyoiC3UMNAhZ86uwi jt2sgEa6jsZylfQUeg6lO4lND83gAA==
ralexm.li.		1500	IN	NSEC	ralexm.li. A NS SOA TXT AAAA RRSIG NSEC DNSKEY
ralexm.li.		1500	IN	RRSIG	NSEC 13 2 1500 20230202000000 20230112000000 35571 ralexm.li. yfinvzyxI1j1KpU2xmGeLKmI08f29uvgdGVd/+AmaW9L1NlXVRyPpw2c GyMhOT92ZY2hIi9S+Qgxv+x03pP5Rg==
...
```

Problem of incorrect NSEC, NSEC3 records:

 * An incorrect NSEC, NSEC3 record can break email delivery to the affected domains when the sending
   system supports DANE.
 * A DNSSEC validating resolver which supports and enables synthesized answers from cached NSEC,
   NSEC3 records (rfc8198) may wrongly return NXDOMAIN or NODATA for other names in the zone.

The typical cause of this incorrect NSEC, NSEC3 records:

 * The most common cause is that the zone is signed with PowerDNS and some tools change
   the zone content by directly accessing the database using SQL where instead it should be using
   the PowerDNS API. See also https://github.com/PowerDNS/pdns/wiki/WebFrontends for a list of 
   WebFrontends known to cause this error.


Install
=======

Dependencies for the scripts:

 * python3 - https://www.python.org/
 * go - https://go.dev/
 * zdns - https://github.com/zmap/zdns

Recommended tools to filter result files:

 * jq - https://stedolan.github.io/jq/

There is a helper script to build and install ZDNS to `go/bin/zdns`:

```bash
utils/install-zdns.sh
```

Usage
=====

Domain List
-----------

You need to create a list of domains to test. If you test all DNSSEC signed domains from a TLD zone
you can create a list of DNSSEC signed domains as following:

```bash
dig -k li_zonedata.key @zonedata.switch.ch +noall +answer +noidnout +onesoa AXFR li. > li.txt
cat li.txt | utils/extract-signed-domain.sh > li-domainlist.txt
```

More information about the public TLD zone access from SWITCH at https://zonedata.switch.ch/


Run Measurement
---------------

Usage:

```bash
Usage: ./run-survey.sh [-n <name-server>] [-t threads] <prefix>
     <prefix>          prefix name for input- and output files e.g. XXX-domainlist.txt

 optional arguments:
     -n <name-server>  list of name servers to use. can be passed as comma-delimited string. optional port can be specified, default 1.1.1.1:53
     -t <threads>      set the number of zdns threads, default 256
```

To start the measurement run the following command:

```bash
./run-survey.sh li
```

Description of the measurement:

The `run-survey.sh` script runs one ZDNS measurement. It checks all domain names listed in the `li-domainlist.txt`
by appending the "www." prefix and querying for the NULL record. The ZDNS output is written to `li-nodata.jsonlines`.

The `run-survey.sh` script starts the `analyze-result.py` script for you.
The `analyze-result.py` script does no measurements but analyzes the result file and prints a summary with
statistics to stdout and writes a list of affected domains to `li-lying.jsonlines`.

You can filter the final result with `jq` further. For example, if you want a list of affected domains by operator XYZ
then run a command similar as following:

```bash
cat li-lying.jsonlines | jq -r 'select(.soa_ns | contains("XYZ")) | .name' | sort > XYZ.txt
```

