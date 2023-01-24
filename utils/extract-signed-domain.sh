#!/bin/bash

egrep "\sIN\s+DS\s" | awk '{print $1}' | grep -v ^\; | sed 's/\.$//' | tr A-Z a-z | uniq
