#!/usr/bin/env sh
set -eu

: "${NEWAPI_PG_PASSWORD:?NEWAPI_PG_PASSWORD is required}"

psql --username "$POSTGRES_USER" --dbname postgres --set ON_ERROR_STOP=1 \
  --set newapi_password="$NEWAPI_PG_PASSWORD" <<'EOSQL'
CREATE ROLE newapi LOGIN PASSWORD :'newapi_password';
CREATE DATABASE newapi OWNER newapi;
EOSQL
