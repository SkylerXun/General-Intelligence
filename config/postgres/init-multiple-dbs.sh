#!/usr/bin/env sh
set -eu

: "${NEWAPI_PG_PASSWORD:?NEWAPI_PG_PASSWORD is required}"
: "${SUB2API_PG_PASSWORD:?SUB2API_PG_PASSWORD is required}"

psql --username "$POSTGRES_USER" --dbname postgres --set ON_ERROR_STOP=1 \
  --set newapi_password="$NEWAPI_PG_PASSWORD" \
  --set sub2api_password="$SUB2API_PG_PASSWORD" <<'EOSQL'
CREATE ROLE newapi LOGIN PASSWORD :'newapi_password';
CREATE DATABASE newapi OWNER newapi;
CREATE ROLE sub2api LOGIN PASSWORD :'sub2api_password';
CREATE DATABASE sub2api OWNER sub2api;
EOSQL
