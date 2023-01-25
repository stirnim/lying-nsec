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
 * jq - https://stedolan.github.io/jq/

There is a helper script to build and install ZDNS to `go/bin/zdns`:

```bash
utils/install-zdns.sh
```


Usage
=====

Domain List:

You need to create a list of domains to test. If you test all DNSSEC signed domains from a TLD zone
you can create a list of DNSSEC signed domains as following:

```bash
dig -k li_zonedata.key @zonedata.switch.ch +noall +answer +noidnout +onesoa AXFR li. > li.txt
cat li.txt | utils/extract-signed-domain.sh > li-domainlist.txt
```

More information about the public TLD zone access from SWITCH at https://zonedata.switch.ch/

Usage:

```bash
Usage: ./run-survey.sh [-n <name-server>] [-t threads] <prefix>
     <prefix>          prefix name for input- and output files e.g. XXX-domainlist.txt

 optional arguments:
     -n <name-server>  list of name servers to use. can be passed as comma-delimited string. optional port can be specified, default 1.1.1.1:53
     -t <threads>      set the number of zdns threads, default 256
```

If you run the measurement to aggressive (high number of threads) it likely results in some TIMEOUT or SERVFAIL responses.
Check the ZDNS output files and reduce the number of threads until the target name-servers can handle it.


To start the measurement run the following command:

```bash
./run-survey.sh li
```

With the `li` script argument, the script will test all domains in the file `li-domainlist.txt`.
There are two ZDNS measurements executed. The first ZDNS run checks all domain names by appending the "www."
prefix and by querying for the A record e.g. input:`mydomain.li`, lookup:`www.mydomain.li/A`.
The ZDNS output is written to `li-www.jsonlines`. A list of domain names where the www hostname
exists (NOERROR response) is written to `li-www-domainlist.txt`.
The second ZDNS run checks the domain names in `li-www-domainlist.txt` by querying for the NULL record.
This is expected to trigger a NODATA response. e.g. input: `mydomain.li`, lookup:`mydomain.li/NULL`.
The ZDNS output is written to `li-nodata.jsonlines`.

After the measurement is done, the `analyze-result.py` script is started which analyses the last
output file and prints a summary with statistics to stdout and writes a list of jsonlines with 
affected domains to `li-lying.jsonlines`.

You can filter the final result with `jq` further. For example, if you want a list of affected
domains by operator XYZ then run a command similar as following:

```bash
cat li-lying.jsonlines | jq -r 'select(.soa_ns | contains("XYZ")) | .name' | sort > XYZ.txt
```


Measurement Notes
=================

Ultimatively we want to get a NODATA response with a proof denying the existance of the www hostname but where it
exists. If we would run the measurement with only one ZDNS measurement where we lookup  `www.<domain>/NULL` we risk
that the recursive resolver synthesizes the response and we fail to detect the error condition. Even if we use a
recursive resolver where aggressive use of DNSSEC-validated cache (rfc8198) is disabled, a single query as shown 
bevore may fail DNSSEC validation (SERVFAIL response).

I found the implemented work-around with two measurements yealds a good result. So, the script first tests
`www.<domain>/A` and if that exists, it follows up with `<domain>/NULL`.

In theory, it could report false positives e.g. if the domain is using NSEC3 opt-out and www is an unsigned delegation.
As NSEC3 opt-out is extremely rarely used outside delegation centric zones such as TLDs it is very unlikely that
we trigger this condition.

