#!/bin/bash

MONTH="$1"
OUTDIR="$2"
SOURCE="$3"

set -eu

[ -z "$OUTDIR" ] && OUTDIR="/dataset"

if [ "$1" == "--help" -o -z "$MONTH" ]; then
  echo "Usage: $0 MONTH [OUTDIR [SOURCE]]"
  echo "Example: $0 2018-01"
  echo "Example: $0 2018-01 /dataset"
  echo "Example: $0 2018-01 /dataset /datasource"
  exit 1
fi

for DAY in {01..31}; do
  /scripts/prepare-day.sh "$MONTH-$DAY" "$OUTDIR/$MONTH" "$SOURCE"
done

