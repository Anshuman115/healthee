"""Locate the knowledge corpus (``packages/knowledge``) in both layouts.

In the dev tree it sits at ``<repo>/packages/knowledge``; the Docker image copies
it to ``/app/packages/knowledge`` and sets ``HEALTHEE_KNOWLEDGE_DIR``. Resolving by
walking up from ``__file__`` breaks in the image (the corpus isn't a parent of the
installed package), so callers must use this helper rather than a fixed
``parents[n]`` offset.
"""

from __future__ import annotations

import os
from pathlib import Path


def knowledge_dir() -> Path:
    """Directory holding ``manifest.json`` + the ``notes/`` and ``sports-science/``
    trees. Prefers ``HEALTHEE_KNOWLEDGE_DIR``, then an upward search from this file,
    then the image default."""
    env = os.environ.get("HEALTHEE_KNOWLEDGE_DIR")
    if env:
        return Path(env)
    for parent in Path(__file__).resolve().parents:
        candidate = parent / "packages" / "knowledge"
        if (candidate / "manifest.json").is_file():
            return candidate
    return Path("/app/packages/knowledge")
