"""Public mission content. Answer keys are deliberately kept elsewhere."""

from __future__ import annotations

from copy import deepcopy
from typing import Any


LEVEL_1_MISSION: dict[str, Any] = {
    "id": "level-1",
    "slug": "radar-rookie",
    "level": 1,
    "title": "Radar Rookie",
    "tagline": "Learn what a radar satellite actually sees.",
    "briefing": (
        "Train on radar concepts before interpreting satellite observations. "
        "These questions are simulations and do not contain real flood findings."
    ),
    "training_only": True,
    "tasks": [
        {
            "id": "1.1",
            "title": "How Radar Sees",
            "prompt": (
                "A synthetic satellite radar sends microwave pulses toward "
                "Earth. What measurement is used to form its image?"
            ),
            "options": [
                {
                    "id": "A",
                    "label": "The strength of microwave energy returned to the sensor",
                },
                {"id": "B", "label": "The surface's visible-light color"},
                {"id": "C", "label": "The temperature of the ground"},
            ],
            "xp": 100,
            "released": True,
            "training_only": True,
        },
        {
            "id": "1.2",
            "title": "Power to Decibels",
            "prompt": (
                "For positive linear radar power, which formula converts a "
                "value to decibels?"
            ),
            "options": [
                {"id": "A", "label": "20 × log10(power)"},
                {"id": "B", "label": "10 × log10(power)"},
                {"id": "C", "label": "power × 10"},
            ],
            "xp": 100,
            "released": False,
            "training_only": True,
        },
        {
            "id": "1.3",
            "title": "Water, Carefully",
            "prompt": (
                "In this training example only, the threshold is −15 dB. "
                "A valid pixel measures −18 dB. What does the classifier report?"
            ),
            "options": [
                {"id": "A", "label": "A threshold-derived water observation"},
                {"id": "B", "label": "A confirmed flood"},
                {"id": "C", "label": "No observation because −18 dB is above −15 dB"},
            ],
            "xp": 100,
            "released": False,
            "training_only": True,
        },
        {
            "id": "1.4",
            "title": "Read the Evidence",
            "prompt": (
                "A pixel is classified as water after an observation but not "
                "before it. What can this comparison establish?"
            ),
            "options": [
                {
                    "id": "A",
                    "label": "A confirmed flood and its exact start time",
                },
                {
                    "id": "B",
                    "label": "An observed water-extent change that needs independent interpretation",
                },
                {"id": "C", "label": "That the satellite measured rainfall"},
            ],
            "xp": 100,
            "released": False,
            "training_only": True,
        },
    ],
}


def list_missions() -> list[dict[str, Any]]:
    """Return client-safe mission content without grading keys."""

    return [deepcopy(LEVEL_1_MISSION)]


def get_task(task_id: str) -> dict[str, Any]:
    for task in LEVEL_1_MISSION["tasks"]:
        if task["id"] == task_id:
            return task
    raise KeyError(task_id)
