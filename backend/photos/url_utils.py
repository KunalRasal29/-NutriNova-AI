from urllib.parse import urlparse, urlunparse


def public_image_url(image, request=None) -> str:
    if not image:
        return ""

    url = image.url
    if not request:
        return url

    absolute_url = request.build_absolute_uri(url)
    parsed = urlparse(absolute_url)
    if parsed.hostname != "minio":
        return absolute_url

    request_host = request.get_host().split(":", 1)[0]
    minio_port = parsed.port or 9000
    return urlunparse(parsed._replace(netloc=f"{request_host}:{minio_port}"))
