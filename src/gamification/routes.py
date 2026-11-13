"""Routes mounted on the existing local TERRALENS FastAPI application."""

import os
from uuid import UUID

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .grading import InvalidAnswerError, UnknownTaskError
from .missions import list_missions
from .store import (
    SubmissionConflictError,
    TaskLockedError,
    get_player_progress,
    get_research_journal,
    reset_player_progress,
    submit_answer,
)


router = APIRouter(prefix="/api/gamification", tags=["gamification"])


class AnswerSubmission(BaseModel):
    submission_id: UUID
    task_id: str = Field(min_length=1, max_length=16)
    answer: str = Field(min_length=1, max_length=8)


@router.get("/missions")
def missions(player_id: UUID | None = None) -> dict[str, object]:
    completed_task_ids: list[str] = []
    if player_id is not None:
        progress = get_player_progress(str(player_id))
        completed_task_ids = progress["completed_task_ids"]
    return {"missions": list_missions(completed_task_ids)}


def development_reset_enabled() -> bool:
    return (
        os.environ.get("TERRALENS_ENV", "").strip().lower() == "development"
        and os.environ.get("TERRALENS_ENABLE_GAMIFICATION_RESET", "")
        .strip()
        .lower()
        in {"1", "true", "yes"}
    )


@router.get("/config")
def config() -> dict[str, bool]:
    return {"development_reset_enabled": development_reset_enabled()}


@router.post("/players/{player_id}/answers")
def answers(player_id: UUID, submission: AnswerSubmission) -> dict[str, object]:
    try:
        return submit_answer(
            str(player_id),
            str(submission.submission_id),
            submission.task_id,
            submission.answer,
        )
    except UnknownTaskError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except InvalidAnswerError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except TaskLockedError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except SubmissionConflictError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.get("/players/{player_id}/progress")
def progress(player_id: UUID) -> dict[str, object]:
    return get_player_progress(str(player_id))


@router.get("/players/{player_id}/journal")
def journal(player_id: UUID) -> dict[str, object]:
    return get_research_journal(str(player_id))


@router.post("/players/{player_id}/reset")
def reset(player_id: UUID) -> dict[str, object]:
    if not development_reset_enabled():
        raise HTTPException(status_code=404, detail="Not found.")
    return {
        "reset": True,
        "training_only": True,
        "progress": reset_player_progress(str(player_id)),
    }
