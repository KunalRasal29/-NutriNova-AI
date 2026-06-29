from rest_framework.throttling import (
    AnonRateThrottle,
    ScopedRateThrottle,
    UserRateThrottle,
)


class AnonymousRateThrottle(AnonRateThrottle):
    scope = "anon"


class AuthenticatedRateThrottle(UserRateThrottle):
    scope = "user"


class PhotoUploadRateThrottle(ScopedRateThrottle):
    scope = "photo_upload"


class QuickAddRateThrottle(ScopedRateThrottle):
    scope = "quick_add"
