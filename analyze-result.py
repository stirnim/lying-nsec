#!/usr/bin/env python3

import argparse
import sys
import json
import traceback

parser = argparse.ArgumentParser(description = 'Lying NSEC, NSEC3 result parser. Shows\
 Top 10 statistics by default, optionally writes list of affected domains to file.')
parser.add_argument("inputfile", help="input file")
parser.add_argument('-o', metavar="outfile", help='output file as jsonlines with\
 affected domains', required=False)
args = parser.parse_args()

lying = dict()
soa_ns = dict()
soa_mbox = dict()
powerdns_count = 0
nsec_count = 0

with open(args.inputfile) as fp:
    for line in fp:
        is_lying_nsec = False
        ns = ""
        mbox = ""
        domain = ""
        zonecut = ""
        nsec_name = ""
        nsec_nextname = ""
        rrsig_inception = ""
        is_powerdns = False
        is_nsec3 = False
        try:
            data = json.loads(line)

            # skip results if not NOERROR response
            # reason: we are interested in NODATA response
            # and not NXDOMAIN response
            if data["status"] != "NOERROR":
                continue

            # skip results where we don't have an
            # authority section
            if not "authorities" in data["data"]:
                continue

            domain = data["name"].lower()

            # parse NODATA response (authority section)
            auth = data["data"]["authorities"]
            for rr in auth:
                # if we found a lying NSEC chain we don't parse any other NSEC record
                if rr["type"] == "NSEC" and not is_lying_nsec:
                    # zdns omits 'name' if empty. final dot is omitted in zdns output.
                    # thus this case typically applies ot the name '.'
                    if "name" in rr:
                        nsec_name = rr["name"].lower()
                    nsec_nextname = rr["next_domain"].lower()
                    if nsec_name != "" and nsec_name == nsec_nextname:
                        is_lying_nsec = True
                        nsec_count += 1
                # if we found a lying NSEC3 chain we don't parse any other NSEC3 record
                if rr["type"] == "NSEC3" and not is_lying_nsec:
                    # zdns omits 'name' if empty. final dot is omitted in zdns output.
                    # thus this case typically applies ot the name '.'
                    if "name" in rr:
                        nsec_name = rr["name"].lower()
                    nsec_nextname = rr["next_domain"].lower()
                    if nsec_name != "" and nsec_name.startswith(nsec_nextname):
                        is_lying_nsec = True
                        is_nsec3 = True
                if rr["type"] == "SOA":
                    ns = rr["ns"].lower()
                    mbox = rr["mbox"].lower()
                    # zdns omits 'name' if empty. final dot is omitted in zdns output.
                    # thus this case typically applies ot the name '.'
                    if "name" in rr:
                        zonecut = rr["name"].lower()
                if rr["type"] == "RRSIG":
                    rrsig_inception = rr["inception"]

            # Revert lying boolean if domain and zonecut is not the same
            # This likely means www is delegated and it is possible that no
            # other hostname beside www exist in this www-subzone.
            if domain != zonecut:
                is_lying_nsec = False
            
            # store lying NSEC, NSEC3 response and update counters
            if is_lying_nsec:
                # PowerDNS seems to be the only signer producing these timestamps
                # https://doc.powerdns.com/authoritative/dnssec/modes-of-operation.html#signatures
                if str(rrsig_inception).endswith("0000"):
                    is_powerdns = True
                    powerdns_count += 1
                lying[domain] = { "name": domain,
                                  "soa_ns": ns,
                                  "soa_mbox": mbox,
                                  "is_powerdns": is_powerdns,
                                  "is_nsec3": is_nsec3,
                                  "nsec_name": nsec_name,
                                  "nsec_nextname": nsec_nextname}
                if ns in soa_ns:
                    soa_ns[ns] += 1
                else:
                    soa_ns[ns] = 1
                if mbox in soa_mbox:
                    soa_mbox[mbox] += 1
                else:
                    soa_mbox[mbox] = 1
        except KeyError:
            print("Failed to parse the line:")
            print(line)
            print("")
            print("Stack trace:")
            print(traceback.format_exc())
            sys.exit(1)


# print summary / statistics
top_soa_ns = sorted(soa_ns.items(), key=lambda x:-x[1])[:10]
top_soa_mbox = sorted(soa_mbox.items(), key=lambda x:-x[1])[:10]

print(f"Found {len(lying)} domains with a lying NSEC or NSEC3 chain, of which:")
print(f" - {nsec_count} use NSEC")
print(f" - {len(lying) - nsec_count} use NSEC3")
print(f" - {powerdns_count} use PowerDNS")
print("")
top_soa_ns_count = 0
for key, value in top_soa_ns:
    top_soa_ns_count += value
print(f"Top 10 SOA ns used ({top_soa_ns_count}/{len(lying)})")
for key, value in top_soa_ns:
    print("    {}: {}".format(value, key))
print("")
top_soa_mbox_count = 0
for key, value in top_soa_mbox:
    top_soa_mbox_count += value
print(f"Top 10 SOA mbox used ({top_soa_mbox_count}/{len(lying)})")
for key, value in top_soa_mbox:
    print("    {}: {}".format(value, key))

# optionally write results to file
if args.o:
    with open(args.o, "w",  encoding='utf-8') as f:
        for line in lying.values():
            f.write(json.dumps(line) + "\n")
