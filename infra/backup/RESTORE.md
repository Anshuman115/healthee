# Restore drill — Healthee Postgres

Backups are dated, gzipped `pg_dump` plain-SQL files written by
`pg_dump_backup.sh` to `$BACKUP_DIR` (default `/var/backups/healthee`), named
`healthee_YYYY-MM-DD_HHMMSS.sql.gz`. A backup you have never restored is a
backup you do not have — **rehearse this quarterly** using the dry-run below.

All commands assume you are in the repo root on the VPS and
`COMPOSE="docker compose --env-file infra/.env -f infra/docker/docker-compose.prod.yml"`.

## 0. Pick the dump

```sh
ls -lh /var/backups/healthee/            # newest is usually the target
DUMP=/var/backups/healthee/healthee_2026-07-15_033000.sql.gz
gzip -t "$DUMP" && echo "gzip integrity OK"   # verify it is not truncated
```

## 1. Dry run — restore into a SCRATCH database (does NOT touch prod)

This is the safe rehearsal. It loads the dump into a throwaway DB alongside the
live one and checks row counts, then drops it. Prod is never modified.

```sh
# Create a scratch DB on the same server.
$COMPOSE exec -T db createdb -U "$POSTGRES_USER" healthee_restore_test

# Load the dump into it.
gunzip -c "$DUMP" | $COMPOSE exec -T db \
    psql -U "$POSTGRES_USER" -d healthee_restore_test -v ON_ERROR_STOP=1

# Sanity-check: list tables + a couple of row counts.
$COMPOSE exec -T db psql -U "$POSTGRES_USER" -d healthee_restore_test \
    -c "\dt" -c "SELECT count(*) FROM sample;"

# Tear down the scratch DB.
$COMPOSE exec -T db dropdb -U "$POSTGRES_USER" healthee_restore_test
```

If that completes without error, the backup is restorable.

## 2. Real restore (disaster recovery — OVERWRITES prod data)

Only after confirming you truly want to replace live data.

```sh
# 1. Stop the api so nothing writes mid-restore.
$COMPOSE stop api

# 2. Drop + recreate the live database.
$COMPOSE exec -T db dropdb   -U "$POSTGRES_USER" "$POSTGRES_DB"
$COMPOSE exec -T db createdb -U "$POSTGRES_USER" "$POSTGRES_DB"

# 3. Load the dump.
gunzip -c "$DUMP" | $COMPOSE exec -T db \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1

# 4. Bring the api back and confirm health.
$COMPOSE up -d api
curl -fsS http://127.0.0.1:8765/healthz && echo "  api healthy"
```

## Notes

- **TimescaleDB**: plain `pg_dump`/`psql` restore works because the image ships
  the `timescaledb` extension; the dump recreates hypertables from the schema.
  If a restore warns about the extension, run
  `CREATE EXTENSION IF NOT EXISTS timescaledb;` in the fresh DB before loading.
- **`ON_ERROR_STOP=1`** makes `psql` abort on the first error instead of
  limping through a half restore — always use it.
- Keep at least one dump **off-box** (set `OFFBOX_CMD` in `infra/.env`); a
  backup on the same VPS does not survive losing the VPS.
