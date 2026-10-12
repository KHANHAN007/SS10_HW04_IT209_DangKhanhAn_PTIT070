#!/usr/bin/env bash
set -euo pipefail

docker network inspect app-net >/dev/null 2>&1 ||
  docker network create --driver bridge app-net

docker volume inspect db-data >/dev/null 2>&1 ||
  docker volume create db-data


docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=LabPassword123 \
  -e POSTGRES_DB=appdb \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine

ready=false
for attempt in {1..30}; do
  if docker exec db-server pg_isready -U appuser -d appdb; then
    ready=true
    break
  fi
  sleep 2
done

if [ "$ready" != true ]; then
  docker logs db-server
  exit 1
fi


docker run -d \
  --name app-container \
  --network app-net \
  -p 8081:3000 \
  -e PGHOST=db-server \
  -e PGPORT=5432 \
  -e PGUSER=appuser \
  -e PGPASSWORD=LabPassword123 \
  -e PGDATABASE=appdb \
  hw-backend:v1
