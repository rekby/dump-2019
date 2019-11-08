#!/bin/bash

DAY="$1"
OUTDIR="$2"
SOURCE="$3"

set -eu

[ -z "$OUTDIR" ] && OUTDIR="/dataset"

if [ "$1" == "--help" -o -z "$DAY" ]; then
  echo "Usage: $0 DAY [OUTDIR [SOURCE]]"
  echo "Example: $0 2018-01-20"
  echo "Example: $0 2018-01-20 /dataset"
  echo "Example: $0 2018-01-20 /dataset /datasource"
  exit 1
fi

if [ -z "$SOURCE" ]; then
  if [ -n "$(ls /datasource)" ]; then
    SOURCE="/datasource"
  else
    SOURCE="https://data.gharchive.org"
  fi
fi

[ -e converter.py ] || cd scripts

echo $OUTDIR $DAY
mkdir -p "$OUTDIR/$DAY"
python3 converter.py --outfile-prefix="$OUTDIR/$DAY/$DAY" --gzip $SOURCE/${DAY}-{0..23}.json.gz
