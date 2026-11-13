"""SQLite persistence for local TERRALENS training progress."""

from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, timezone
import json
from pathlib import Path
import sqlite3
from typing import Iterator
from uuid import UUID

from .grading import Grade, grade_answer
from .missions import LEVEL_1_MISSION, get_task


ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "cache" / "gamification.sqlite3"
RANKS = (
    (0, "Signal Seeker"),
    (100, "Radar Rookie"),
    (300, "Change Detective"),
    (600, "Earth Systems Analyst"),
)


class SubmissionConflictError(ValueError):
    """Raised when an idempotency key is reused for another task."""


def rank_for_xp(total_xp: int) -> dict[str, int | str | None]:
    rank_index = max(
        index for index, (minimum_xp, _) in enumerate(RANKS)
        if total_xp >= minimum_xp
    )
    minimum_xp, name = RANKS[rank_index]
    next_rank = RANKS[rank_index + 1] if rank_index + 1 < len(RANKS) else None
    return {
        "name": name,
        "minimum_xp": minimum_xp,
        "next_rank": next_rank[1] if next_rank else None,
        "xp_to_next": next_rank[0] - total_xp if next_rank else None,
    }


def _normalize_uuid(value: str) -> str:
    try:
        return str(UUID(value))
    except (ValueError, AttributeError) as error:
        raise ValueError("Player and submission IDs must be valid UUIDs.") from error


@contextmanager
def _database(db_path: Path | None = None) -> Iterator[sqlite3.Connection]:
    path = db_path or DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path, timeout=10, isolation_level=None)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.executescript(
        """
        CREATE TABLE IF NOT EXISTS players (
            player_id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS task_completions (
            player_id TEXT NOT NULL REFERENCES players(player_id),
            task_id TEXT NOT NULL,
            xp_awarded INTEGER NOT NULL,
            completed_at TEXT NOT NULL,
            PRIMARY KEY (player_id, task_id)
        );
        CREATE TABLE IF NOT EXISTS submissions (
            player_id TEXT NOT NULL REFERENCES players(player_id),
            submission_id TEXT NOT NULL,
            task_id TEXT NOT NULL,
            answer TEXT NOT NULL,
            correct INTEGER NOT NULL,
            xp_awarded INTEGER NOT NULL,
            response_json TEXT NOT NULL,
            submitted_at TEXT NOT NULL,
            PRIMARY KEY (player_id, submission_id)
        );
        """
    )
    try:
        yield connection
    finally:
        connection.close()


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ensure_player(connection: sqlite3.Connection, player_id: str) -> None:
    connection.execute(
        "INSERT OR IGNORE INTO players (player_id, created_at) VALUES (?, ?)",
        (player_id, _timestamp()),
    )


def _total_xp(connection: sqlite3.Connection, player_id: str) -> int:
    row = connection.execute(
        "SELECT COALESCE(SUM(xp_awarded), 0) AS total FROM task_completions "
        "WHERE player_id = ?",
        (player_id,),
    ).fetchone()
    return int(row["total"])


def _progress_payload(
    connection: sqlite3.Connection,
    player_id: str,
) -> dict[str, object]:
    completed = connection.execute(
        "SELECT task_id FROM task_completions WHERE player_id = ? ORDER BY task_id",
        (player_id,),
    ).fetchall()
    completed_task_ids = [row["task_id"] for row in completed]
    completed_set = set(completed_task_ids)
    task_ids = [task["id"] for task in LEVEL_1_MISSION["tasks"]]
    completed_count = sum(task_id in completed_set for task_id in task_ids)
    total_xp = _total_xp(connection, player_id)
    return {
        "player_id": player_id,
        "total_xp": total_xp,
        "rank": rank_for_xp(total_xp),
        "completed_task_ids": completed_task_ids,
        "missions": [
            {
                "mission_id": LEVEL_1_MISSION["id"],
                "completed_tasks": completed_count,
                "total_tasks": len(task_ids),
                "completed": completed_count == len(task_ids),
            }
        ],
    }


def get_player_progress(player_id: str) -> dict[str, object]:
    player_id = _normalize_uuid(player_id)
    with _database() as connection:
        connection.execute("BEGIN IMMEDIATE")
        _ensure_player(connection, player_id)
        payload = _progress_payload(connection, player_id)
        connection.commit()
        return payload


def _submission_payload(
    player_id: str,
    submission_id: str,
    task_id: str,
    grade: Grade,
    xp_awarded: int,
    total_xp: int,
    *,
    duplicate_submission: bool = False,
    already_completed: bool = False,
) -> dict[str, object]:
    return {
        "player_id": player_id,
        "submission_id": submission_id,
        "task_id": task_id,
        "correct": grade.correct,
        "correct_answer": grade.correct_answer,
        "explanation": grade.explanation,
        "xp_awarded": xp_awarded,
        "total_xp": total_xp,
        "rank": rank_for_xp(total_xp),
        "duplicate_submission": duplicate_submission,
        "already_completed": already_completed,
        "training_only": True,
    }


def submit_answer(
    player_id: str,
    submission_id: str,
    task_id: str,
    answer: str,
) -> dict[str, object]:
    player_id = _normalize_uuid(player_id)
    submission_id = _normalize_uuid(submission_id)
    grade = grade_answer(task_id, answer)
    normalized_answer = answer.strip().upper()

    with _database() as connection:
        connection.execute("BEGIN IMMEDIATE")
        _ensure_player(connection, player_id)
        previous = connection.execute(
            "SELECT task_id, response_json FROM submissions "
            "WHERE player_id = ? AND submission_id = ?",
            (player_id, submission_id),
        ).fetchone()
        if previous is not None:
            if previous["task_id"] != task_id:
                connection.rollback()
                raise SubmissionConflictError(
                    "This submission ID has already been used for another task."
                )
            response = json.loads(previous["response_json"])
            response["xp_awarded"] = 0
            response["duplicate_submission"] = True
            response["total_xp"] = _total_xp(connection, player_id)
            response["rank"] = rank_for_xp(response["total_xp"])
            connection.commit()
            return response

        completed = connection.execute(
            "SELECT 1 FROM task_completions WHERE player_id = ? AND task_id = ?",
            (player_id, task_id),
        ).fetchone()
        if completed is not None:
            total_xp = _total_xp(connection, player_id)
            response = _submission_payload(
                player_id,
                submission_id,
                task_id,
                grade,
                0,
                total_xp,
                duplicate_submission=True,
                already_completed=True,
            )
            connection.commit()
            return response

        task = get_task(task_id)
        xp_awarded = grade.xp_value if grade.correct else 0
        submitted_at = _timestamp()
        if grade.correct:
            connection.execute(
                "INSERT INTO task_completions "
                "(player_id, task_id, xp_awarded, completed_at) VALUES (?, ?, ?, ?)",
                (player_id, task_id, xp_awarded, submitted_at),
            )
        total_xp = _total_xp(connection, player_id)
        response = _submission_payload(
            player_id,
            submission_id,
            task_id,
            grade,
            xp_awarded,
            total_xp,
        )
        connection.execute(
            """
            INSERT INTO submissions
                (player_id, submission_id, task_id, answer, correct,
                 xp_awarded, response_json, submitted_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                player_id,
                submission_id,
                task_id,
                normalized_answer,
                int(grade.correct),
                xp_awarded,
                json.dumps(response),
                submitted_at,
            ),
        )
        connection.commit()
        return response


def get_research_journal(player_id: str) -> dict[str, object]:
    player_id = _normalize_uuid(player_id)
    with _database() as connection:
        connection.execute("BEGIN IMMEDIATE")
        _ensure_player(connection, player_id)
        rows = connection.execute(
            """
            SELECT task_id, answer, correct, xp_awarded, submitted_at, response_json
            FROM submissions
            WHERE player_id = ?
            ORDER BY submitted_at DESC, submission_id DESC
            """,
            (player_id,),
        ).fetchall()
        entries = []
        for row in rows:
            task = get_task(row["task_id"])
            response = json.loads(row["response_json"])
            entries.append(
                {
                    "task_id": row["task_id"],
                    "task_title": task["title"],
                    "answer": row["answer"],
                    "correct": bool(row["correct"]),
                    "xp_awarded": row["xp_awarded"],
                    "submitted_at": row["submitted_at"],
                    "explanation": response["explanation"],
                    "training_only": True,
                }
            )
        connection.commit()
    return {"player_id": player_id, "entries": entries}
