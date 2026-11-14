#!/usr/bin/env bash
# runs each test file, prints TAP, fails if any 'not ok'
o=$(for f in "$@"; do bash "$f" 2>&1; done); echo "$o"; ! echo "$o" | grep -q '^not ok'
