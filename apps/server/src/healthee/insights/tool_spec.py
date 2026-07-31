"""The OpenAI function-tool spec shape — one definition, two tool modules.

``coach_tools`` and ``challenge_tools`` both declare tools the coach may call, and the
wire shape belongs to the client rather than to either of them. A second hand-rolled
copy of it is a second thing that can drift from what ``client.complete`` actually
sends (standards §Duplication), and a drifted spec fails as a model that silently
stops calling a tool — the quietest failure this surface has.

Nothing here decides anything: it is a constructor for a dict.
"""

from __future__ import annotations

from typing import Any


def function_tool(
    name: str, description: str, properties: dict[str, Any], required: list[str]
) -> dict:
    """One OpenAI function-tool spec (the shape the LLM client passes through)."""
    return {
        "type": "function",
        "function": {
            "name": name,
            "description": description,
            "parameters": {"type": "object", "properties": properties, "required": required},
        },
    }
