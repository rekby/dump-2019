#!/bin/bash

set -eu

DATABASE="$1"
QUERY="$2"

case "$DATABASE" in
  clickhouse)
    exec docker-compose exec -T clickhouse clickhouse-client --progress --multiquery <<< "$QUERY"
    ;;
  elasticsearch)
    QUERY="${QUERY/\\/\\\\}"
    QUERY="${QUERY//\"/\\\"}"
    curl -H "Content-type: application/json" 'http://localhost:9200/_sql?format=txt' -d "{\"query\": \"$QUERY\"}"
    ;;
  memsql)
    exec docker-compose exec -T memsql memsql test <<< "$QUERY"
    ;;
  postgres*|timescale)
    exec docker-compose exec -T $DATABASE psql -U postgres postgres <<< "$QUERY"
    ;;
  *)
    echo "Unknown db: '$DATABASE'"
    ;;
esac