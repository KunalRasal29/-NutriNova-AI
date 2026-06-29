# Database Backup Notes

Production NutriNova AI deployments should run automated PostgreSQL backups before real user data is stored.

## Local Manual Backup

```bash
docker compose exec postgres pg_dump -U nutrinova -d nutrinova > nutrinova_backup.sql
```

Restore locally:

```bash
docker compose exec -T postgres psql -U nutrinova -d nutrinova < nutrinova_backup.sql
```

## Production Recommendations

- Use daily full backups and point-in-time recovery if your managed database supports it.
- Encrypt backups at rest.
- Store backups in a different failure domain than the database.
- Test restore procedures regularly.
- Keep a written retention policy.
- Restrict backup access to trusted operators only.
- Do not put database dumps in Git.

## Pre-Launch Checklist

- Confirm restore works in a staging environment.
- Confirm backup retention matches privacy policy promises.
- Confirm deletion requests are reflected in live data and age out of backups according to policy.
