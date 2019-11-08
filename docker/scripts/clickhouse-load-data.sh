#!/bin/bash

DIR="$1"

set -eu

if [ "$DIR" == "--help" ]; then
  echo "Usage: $0 DATADIR"
  echo "Example: $0 /dataset"
  exit 1
fi

[ -z "$DIR" ] && DIR="/dataset"

clickhouse-client -nm < scripts/clickhouse-create-tables.sql

for FILE in $(find "$DIR" -iname "*.csv.gz" | sort); do
  case "$FILE" in
    *issuesevent.csv.gz)
      echo "Import: $FILE"
      gunzip -c "$FILE" | clickhouse-client --date_time_input_format=best_effort --query="INSERT INTO issue_event FORMAT CSV"
      ;;

    *pushevent.csv.gz)
      echo "Import: $FILE"
      gunzip -c "$FILE" | clickhouse-client --date_time_input_format=best_effort --query="INSERT INTO push_event FORMAT CSV"
      ;;

    *)
      echo "Skip: $FILE"
      ;;
  esac
done

#echo Optimize table issue_event
#clickhouse-client <<< "OPTIMIZE TABLE issue_event FINAL"
#
#echo Optimize table push_event
#clickhouse-client <<< "OPTIMIZE TABLE push_event FINAL"
