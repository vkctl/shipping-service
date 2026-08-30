import os


def _truthy(value):
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def is_enabled(name, default=False):
    """Read a feature flag from the environment.

    FEATURE_BULK_DISCOUNT=true  ->  is_enabled("bulk_discount") is True
    """
    raw = os.environ.get(f"FEATURE_{name.upper()}")
    if raw is None:
        return default
    return _truthy(raw)


def all_flags():
    return {
        key[len("FEATURE_"):].lower(): _truthy(value)
        for key, value in os.environ.items()
        if key.startswith("FEATURE_")
    }