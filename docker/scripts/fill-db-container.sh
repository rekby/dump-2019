#!/bin/bash

set -eu

DATABASE="$1"
DEST="$2"
FILTER="$3"

date
echo DELETE $DATABASE
sleep 10
docker-compose rm --stop --force $DATABASE
if [ "$DATABASE" == "elasticsearch" ]; then
  docker volume ls -q | grep -q "docker_elasticsearch-data" && docker volume rm docker_elasticsearch-data
fi

date
echo $DATABASE up
docker-compose up -d $DATABASE
sleep 10
if [ "$DATABASE" == "memsql" ]; then
  sleep 5
  echo $DATABASE up once more
  docker-compose up -d $DATABASE
  sleep 10
fi

if [ "$DATABASE" == "elasticsearch" ]; then
  docker-compose up -d logstash
  echo "Sleep for startup processes"
  sleep 60
fi

date
echo $DATABASE create
docker-compose exec $DATABASE /scripts/load-data.sh $DATABASE create

echo $DATABASE import
docker-compose exec $DATABASE /scripts/load-data.sh $DATABASE import "$FILTER"

date
echo $DATABASE finish
docker-compose exec $DATABASE /scripts/load-data.sh $DATABASE finish

sleep 10

date
docker-compose stop $DATABASE

echo detach $DATABASE
SOURCE="$(docker inspect docker_${DATABASE}_1 | jq '.[0].Mounts | map(select(.Type == "volume"))[0].Source' | tr -d '"')"
mv "$SOURCE" "$DEST"

