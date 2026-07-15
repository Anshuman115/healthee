"""Core layer — the shared foundation every other module depends on.

Config (pydantic-settings, the only place env is read), the one DB pool, auth,
notifications, and logging. Nothing here knows about business logic; everything
above depends downward onto it.
"""
