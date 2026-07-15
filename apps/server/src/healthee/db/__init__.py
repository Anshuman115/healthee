"""Database schema + the migration runner.

`schema.sql` is the current-state reference; `migrations/*.sql` is what actually
builds the DB, applied transactionally by `healthee.db.migrate`.
"""
