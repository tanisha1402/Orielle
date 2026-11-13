"""Server-side training answer keys and grading rules."""

from __future__ import annotations

from dataclasses import dataclass

from .missions import get_task


ANSWER_KEYS = {
    "1.1": "A",
    "1.2": "B",
    "1.3": "A",
    "1.4": "B",
}

EXPLANATIONS = {
    "1.1": (
        "Synthetic training answer: SAR records returned microwave "
        "backscatter, not a visible-light photograph or surface temperature."
    ),
    "1.2": (
        "For linear power, the decibel conversion is 10 × log10(power). "
        "The training value is not a TERRALENS scene measurement."
    ),
    "1.3": (
        "−18 dB is at or below the illustrative −15 dB threshold, so this "
        "pixel meets the threshold rule. A threshold label is not ground truth."
    ),
    "1.4": (
        "The comparison establishes an observed extent change only. It cannot "
        "by itself prove flooding, identify a cause, or determine timing."
    ),
}


class UnknownTaskError(ValueError):
    """Raised when an answer references a task outside the mission catalog."""


class InvalidAnswerError(ValueError):
    """Raised when an answer is not one of the task's published choices."""


@dataclass(frozen=True)
class Grade:
    correct: bool
    correct_answer: str
    explanation: str
    xp_value: int


def grade_answer(task_id: str, answer: str) -> Grade:
    try:
        task = get_task(task_id)
        expected = ANSWER_KEYS[task_id]
        explanation = EXPLANATIONS[task_id]
    except KeyError as error:
        raise UnknownTaskError(f"Unknown task: {task_id}") from error

    if not isinstance(answer, str):
        raise InvalidAnswerError("Answer must be a choice ID.")
    normalized = answer.strip().upper()
    valid_options = {option["id"] for option in task["options"]}
    if normalized not in valid_options:
        raise InvalidAnswerError("Answer must match one of the published choices.")

    return Grade(
        correct=normalized == expected,
        correct_answer=expected,
        explanation=explanation,
        xp_value=task["xp"],
    )
