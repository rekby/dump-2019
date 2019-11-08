#!/bin/bash

set -eu

DB="$1"

function query(){
  local QUERY_TYPE="$1"
  local DB="$2"
  case $QUERY_TYPE in
    count) echo "SELECT count(*) FROM push";;
    filter) echo "SELECT COUNT(*) FROM push WHERE actor_login='rekby'";;
    regexp)
      case $DB in
        clickhouse) echo "SELECT count(*) FROM push WHERE extract(repo_name, '(^.*)/') = 'rekby'";;
        memsql) echo "SELECT COUNT(*) FROM push WHERE REGEXP_REPLACE(repo_name, '/.*', '') = 'rekby'";;
        postgres*|timescale) echo "SELECT count(*) FROM push WHERE substring(repo_name from '(^.*)/') = 'rekby'";;
      esac;;
    stat-small)
      case $DB in
        postgres*|timescale) echo "SELECT extract('hour' FROM created_at) AS hour, count(*) AS cnt FROM push GROUP BY hour ORDER BY cnt";;
        clickhouse) echo "SELECT toHour(created_at) AS hour, count(*) AS cnt FROM push GROUP BY hour ORDER BY hour";;
        memsql) echo "SELECT EXTRACT(hour FROM created_at) AS hour, count(*) AS cnt FROM push GROUP BY hour ORDER BY hour";;
      esac;;
    stat)
      case $DB in
      clickhouse)
        echo "SET max_bytes_before_external_group_by=3000000000; SELECT repo_name, count(*) as cnt FROM push GROUP BY repo_name ORDER BY cnt DESC LIMIT 5";;
      *)
        echo "SELECT repo_name, count(*) as cnt FROM push GROUP BY repo_name ORDER BY cnt DESC LIMIT 5";;
      esac;;
    stat-time-limit)
      case $DB in
        clickhouse) echo "SELECT repo_name, count(*) AS cnt FROM push WHERE toDateTime(toDate('2015-06-01')) <= created_at AND created_at < toDateTime(toDate('2015-10-01')) GROUP BY repo_name ORDER BY cnt DESC LIMIT 5 ";;
        memsql) echo "SELECT repo_name, count(*) AS cnt FROM push WHERE '2015-06-01' <= created_at AND created_at < '2015-10-01'  GROUP BY repo_name ORDER BY cnt DESC LIMIT 5 ";;
        postgres*|timescale) echo "SELECT repo_name, count(*) AS cnt FROM push WHERE '2015-06-01' <= created_at AND created_at < '2015-10-01'  GROUP BY repo_name ORDER BY cnt DESC LIMIT 5 ";
      esac;;
    stat-large)
      case $DB in
        clickhouse) echo "SET max_bytes_before_external_group_by=3000000000; SELECT before, count(*) AS cnt FROM push GROUP BY before ORDER BY cnt DESC LIMIT 5";;
        memsql) echo 'SELECT `before`, count(*) AS cnt FROM push GROUP BY `before` ORDER BY cnt DESC LIMIT 5';;
        postgres*|timescale) echo "SELECT before, count(*) AS cnt FROM push GROUP BY before ORDER BY cnt DESC LIMIT 5";;
      esac;;
  esac
}

function test_query(){
  local QUERY_TYPE="$1"
  local DB="$2"

  local QUERY=$(query "$QUERY_TYPE" "$DB")
  local I=""

  declare -a TIMES
  for I in $(seq 3); do
    echo "DB: $DB QUERY: $QUERY_TYPE DATE: $DATE" >&2
    local START=$(date +%s)
    time scripts/check-query.sh "$DB" "$QUERY" >&2
    local FINISH=$(date +%s)
    local DURATION=$((FINISH-START))
    TIMES[$I]=$DURATION
  done
  echo "stat: $DB $QUERY_TYPE: ${TIMES[@]}"
}

for QUERY_TYPE in count filter regexp stat-small stat stat-time-limit stat-large; do
  DATE=$(date)
  test_query "$QUERY_TYPE" $DB
done

