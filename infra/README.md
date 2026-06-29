# Infrastructure

Local development infrastructure is managed by the root `docker-compose.yml`.

Services:

- PostgreSQL for application data
- Redis for Celery broker/result backend
- MinIO for S3-compatible local object storage
- Django backend
- Celery worker
- Celery beat

