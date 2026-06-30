import json
from urllib.parse import urlparse

import boto3
from django.conf import settings
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Ensure the local S3-compatible storage bucket exists for development."

    def handle(self, *args, **options):
        if not getattr(settings, "USE_S3_STORAGE", False):
            self.stdout.write("S3 storage is disabled; no bucket setup needed.")
            return

        bucket_name = settings.AWS_STORAGE_BUCKET_NAME
        endpoint_url = settings.AWS_S3_ENDPOINT_URL
        client = boto3.client(
            "s3",
            endpoint_url=endpoint_url,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=getattr(settings, "AWS_S3_REGION_NAME", "us-east-1"),
            use_ssl=getattr(settings, "AWS_S3_USE_SSL", False),
        )

        existing_buckets = {
            bucket["Name"] for bucket in client.list_buckets().get("Buckets", [])
        }
        if bucket_name not in existing_buckets:
            client.create_bucket(Bucket=bucket_name)
            self.stdout.write(f"Created storage bucket: {bucket_name}")
        else:
            self.stdout.write(f"Storage bucket already exists: {bucket_name}")

        if urlparse(endpoint_url).hostname in {"minio", "localhost", "127.0.0.1"}:
            policy = {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": "*",
                        "Action": ["s3:GetObject"],
                        "Resource": [f"arn:aws:s3:::{bucket_name}/*"],
                    }
                ],
            }
            client.put_bucket_policy(Bucket=bucket_name, Policy=json.dumps(policy))
            self.stdout.write(f"Enabled local public read policy: {bucket_name}")
