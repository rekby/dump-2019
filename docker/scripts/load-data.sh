#!/bin/bash

DATABASE="$1"
ACTION="$2"
FILTER="$3"
DIR="/dataset"

set -eu

if [ "$1" == "--help" ]; then
  echo "Usage: $0 DATABASE ACTION [FILTER]"
  echo "Example: $0 memsql load 2018-"
  exit 1
fi

case "$ACTION" in
  create)
    case "$DATABASE" in
      clickhouse)
        clickhouse-client -nm < /scripts/clickhouse-create-tables.sql
        ;;
      elasticsearch)
         echo pass
         ;;
      memsql)
        memsql < /scripts/memsql-create-tables.sql
        ;;
      postgres1)
        cat /scripts/postgres-create-table1.sql | psql -U postgres postgres
        ;;
      postgres2)
        cat /scripts/postgres-create-table2.sql | psql -U postgres postgres
        ;;
      postgres3)
        cat /scripts/postgres-create-table3.sql | psql -U postgres postgres
        ;;
      postgres4)
        cat /scripts/postgres-create-table4.sql | psql -U postgres postgres
        ;;
      postgres-brin)
        cat /scripts/postgres-create-brin.sql | psql -U postgres postgres
        ;;
      timescale)
        cat /scripts/timescale-create-table.sql | psql -U postgres postgres
        ;;
      *)
        echo "Unknown database '$DATABASE'"
        exit 1
        ;;
    esac
    ;;

  import)
    function import_file(){
      local FILE="$1"

      case "$DATABASE" in
        clickhouse)
          local TABLE="push"
          local INPUT_TABLE="id UInt64, actor_id UInt32, actor_login String, repo_id UInt32, repo_name String, created_at String, head String, before String, size UInt16, distinct_size UInt32"
          local QUERY="INSERT INTO $TABLE SELECT id, actor_id, actor_login, repo_id, repo_name, parseDateTimeBestEffort(created_at) AS created_at, unhex(head) AS head, unhex(before) AS before, size, distinct_size FROM input('$INPUT_TABLE') FORMAT CSV"
          gunzip -c "$FILE" | clickhouse-client --query="$QUERY"
          ;;
        elasticsearch)
          gunzip -c "$FILE" | nc logstash 5046
          ;;
        memsql)
          local TABLE="push"
          local QUERY="LOAD DATA INFILE '$FILE' SKIP ALL ERRORS INTO TABLE $TABLE COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\r\n'\
          (id, actor_id, actor_login, repo_id, repo_name, created_at, @head_hex, @before_hex, size, distinct_size) \
          SET head=UNHEX(@head_hex), \`before\`=UNHEX(@before_hex) \
          ;"
          memsql test <<< "$QUERY"
          ;;
        postgres[1235]|postgres-brin)
          TMP_TABLE="$(cat scripts/postgres-create-table-tmp.sql)"
          local TABLE="push"
          echo "$TMP_TABLE; COPY tmp FROM PROGRAM 'cat $FILE | gunzip' (FORMAT csv, DELIMITER ',', ENCODING 'utf8'); INSERT INTO $TABLE SELECT id, actor_id, actor_login, repo_id, repo_name, created_at, decode(head, 'hex'), decode(before, 'hex'), size, distinct_size FROM tmp ORDER BY repo_name, actor_login, before;" | psql -U postgres postgres
          ;;
        postgres4)
          TMP_TABLE="$(cat scripts/postgres-create-table-tmp.sql)"
          TABLE_BASE=$(basename "$FILE")
          TABLE="push_y${TABLE_BASE:0:4}m${TABLE_BASE:5:2}"
          echo "$TMP_TABLE; COPY tmp FROM PROGRAM 'cat $FILE | gunzip' (FORMAT csv, DELIMITER ',', ENCODING 'utf8'); INSERT INTO $TABLE SELECT id, actor_id, actor_login, repo_id, repo_name, created_at, decode(head, 'hex'), decode(before, 'hex'), size, distinct_size FROM tmp ORDER BY repo_name, actor_login, before;" | psql -U postgres postgres
          ;;
        timescale)
          local TABLE="push"
          echo "COPY $TABLE FROM PROGRAM 'cat $FILE | gunzip' (FORMAT csv, DELIMITER ',', ENCODING 'utf8')" | psql -U postgres postgres
          ;;
        *)
          echo "Unknown database '$DATABASE'"
          exit 1
          ;;
      esac
    }

    for FILE in $(find "$DIR" -iname "*.csv.gz" | grep -- "$FILTER" | sort); do
      case "$FILE" in
        *pushevent.csv.gz)
          echo "Import: $FILE"
          time import_file "$FILE"
          ;;
        *)
          echo "Skip: $FILE"
          ;;
      esac
    done
    ;;

  finish)
      case "$DATABASE" in
        clickhouse)
          time clickhouse-client --multiquery --query="OPTIMIZE TABLE push; OPTIMIZE TABLE push; "
          echo sleep for remove old data files
          sleep 30
          ;;
        elasticsearch)
          echo "sleep wait logstash"
          sleep 20
          curl -X POST 'http://elasticsearch:9200/push_*/_flush'
          ;;
        memsql)
          time memsql test <<< "OPTIMIZE TABLE push FLUSH; OPTIMIZE TABLE push;"
          ;;
        postgres*|timescale)
          time echo "VACUUM ANALYZE" | psql -U postgres postgres
          ;;
        *)
          echo "Unknown database '$DATABASE'"
          exit 1
          ;;
      esac
    ;;
  *)
    echo "Unknowk action: '$ACTION'"
    exit 1
esac
