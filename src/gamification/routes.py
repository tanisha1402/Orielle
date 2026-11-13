"""Routes mounted on the existing local TERRALENS FastAPI application."""

from uuid import UUID

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .grading import InvalidAnswerError, UnknownTaskError
from .missions import list_missions
from .store import (
    SubmissionConflictError,
    get_player_progress,
    get_research_journal,
    submit_answer,
)


router = APIRouter(prefix="/api/gamification", tags=["gamification"])


class AnswerSubmission(BaseModel):
    submission_id: UUID
    task_id: str = Field(min_length=1, max_length=16)
    answer: str = Field(min_length=1, max_length=8)


@router.get("/missions")
def missions() -> dict[str, object]:
    return {"missions": list_missions()}


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
    except SubmissionConflictError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.get("/players/{player_id}/progress")
def progress(player_id: UUID) -> dict[str, object]:
    return get_player_progress(str(player_id))


@router.get("/players/{player_id}/journal")
def journal(player_id: UUID) -> dict[str, object]:
    return get_research_journal(str(player_id))
