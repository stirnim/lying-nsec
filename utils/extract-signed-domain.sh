#!/bin/bash

grep -i "\tDS\t" | awk '{print $1}' | grep -v ^\; | sed 's/\.$//' | tr A-Z a-z | uniq
