#!/usr/bin/env bash
# Throwaway database helper. Usage: scripts/db.sh build | start | fresh [dbname] | stop
#   build  build the Postgres+pgTAP image from docker/Dockerfile
#   start  (re)create the throwaway container for this project (tmpfs data, project mounted read-only at /work)
#   fresh  drop and rebuild one database from zero: apply $SCHEMA_DIR/*.sql, then install pgTAP into schema tap
#   stop   remove the container
# Safety: it only ever touches a container that carries the label decision-lock=1 (or does not exist yet).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
psql_su() { $DOCKER exec -i -u postgres "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 "$@"; }
guard() {
  local label
  label=$($DOCKER inspect -f '{{index .Config.Labels "decision-lock"}}' "$CONTAINER" 2>/dev/null) || return 0
  [ "$label" = "1" ] || { echo "refusing: container $CONTAINER exists and is not a decision-lock container" >&2; exit 2; }
}
build() { $DOCKER build -t "$IMAGE" "$skill_dir/docker"; }
start() {
  guard
  $DOCKER rm -f "$CONTAINER" >/dev/null 2>&1 || true
  $DOCKER run -d --name "$CONTAINER" --label decision-lock=1 -e POSTGRES_HOST_AUTH_METHOD=trust -e TZ=UTC \
    -v "$DL_ROOT":/work:ro --tmpfs /var/lib/postgresql/data:rw "$IMAGE" -c fsync=off >/dev/null
  for _ in $(seq 1 60); do
    $DOCKER exec -u postgres "$CONTAINER" psql -Xqc 'select 1' >/dev/null 2>&1 && return 0; sleep 1
  done
  echo "postgres did not start" >&2; exit 1
}
fresh() {
  guard
  local db=${1:-$DBNAME} f
  psql_su -d postgres -c "DROP DATABASE IF EXISTS $db WITH (FORCE)" -c "CREATE DATABASE $db TEMPLATE template0 ENCODING 'UTF8'"
  for f in $(cd "$DL_ROOT/$SCHEMA_DIR" && ls ./*.sql 2>/dev/null | sort); do
    psql_su -d "$db" -f "/work/$SCHEMA_DIR/${f#./}" >/dev/null
  done
  psql_su -d "$db" -c "CREATE SCHEMA IF NOT EXISTS tap; CREATE EXTENSION IF NOT EXISTS pgtap SCHEMA tap; GRANT USAGE ON SCHEMA tap TO PUBLIC; GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA tap TO PUBLIC;" >/dev/null
}
stop() { guard; $DOCKER rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
cmd=${1:-}; shift || true
case "$cmd" in build|start|fresh|stop) "$cmd" "$@";; *) echo "usage: $0 build|start|fresh [db]|stop" >&2; exit 64;; esac
