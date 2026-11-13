from __future__ import annotations

import asyncio
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from uuid import uuid4

import httpx

from src.api import app
from src.gamification.grading import (
    ANSWER_KEYS,
    InvalidAnswerError,
    UnknownTaskError,
    grade_answer,
)
from src.gamification.missions import list_missions
from src.gamification.store import (
    SubmissionConflictError,
    TaskLockedError,
    get_player_progress,
    get_research_journal,
    rank_for_xp,
    reset_player_progress,
    submit_answer,
)


class GamificationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.database_path = Path(self.temporary.name) / "gamification.sqlite3"
        self.database_patch = patch(
            "src.gamification.store.DB_PATH",
            self.database_path,
        )
        self.database_patch.start()
        self.player_id = str(uuid4())

    def tearDown(self):
        self.database_patch.stop()
        self.temporary.cleanup()

    def test_mission_catalog_has_four_training_tasks_without_answer_keys(self):
        missions = list_missions()
        self.assertEqual(len(missions), 1)
        mission = missions[0]
        self.assertEqual(mission["title"], "Radar Rookie")
        self.assertTrue(mission["training_only"])
        self.assertEqual([task["id"] for task in mission["tasks"]], [
            "1.1", "1.2", "1.3", "1.4"
        ])
        self.assertTrue(all(task["training_only"] for task in mission["tasks"]))
        self.assertTrue(all(task["released"] for task in mission["tasks"]))
        self.assertTrue(mission["tasks"][0]["unlocked"])
        self.assertFalse(mission["tasks"][1]["unlocked"])

        payload = json.dumps(missions)
        self.assertNotIn("correct_answer", payload)
        self.assertNotIn("answer_keys", payload)
        for task_id, answer_key in ANSWER_KEYS.items():
            self.assertNotIn(f'"{task_id}": "{answer_key}"', payload)

    def test_grading_is_server_side_and_validates_choices(self):
        self.assertTrue(grade_answer("1.1", "a").correct)
        self.assertFalse(grade_answer("1.1", "B").correct)
        self.assertEqual(grade_answer("1.1", "A").xp_value, 100)
        with self.assertRaises(InvalidAnswerError):
            grade_answer("1.1", "not-a-choice")
        with self.assertRaises(UnknownTaskError):
            grade_answer("9.9", "A")

    def test_rank_thresholds_are_calculated_from_xp(self):
        self.assertEqual(rank_for_xp(0)["name"], "Signal Seeker")
        self.assertEqual(rank_for_xp(99)["name"], "Signal Seeker")
        self.assertEqual(rank_for_xp(100)["name"], "Radar Rookie")
        self.assertEqual(rank_for_xp(300)["name"], "Change Detective")
        self.assertEqual(rank_for_xp(600)["name"], "Earth Systems Analyst")
        self.assertIsNone(rank_for_xp(600)["next_rank"])

    def test_correct_completion_persists_xp_and_blocks_duplicate_awards(self):
        submission_id = str(uuid4())
        first = submit_answer(self.player_id, submission_id, "1.1", "A")
        self.assertTrue(first["correct"])
        self.assertEqual(first["xp_awarded"], 100)
        self.assertEqual(first["total_xp"], 100)

        replay = submit_answer(self.player_id, submission_id, "1.1", "A")
        self.assertTrue(replay["duplicate_submission"])
        self.assertEqual(replay["xp_awarded"], 0)
        self.assertEqual(replay["total_xp"], 100)

        second_submission = submit_answer(
            self.player_id,
            str(uuid4()),
            "1.1",
            "A",
        )
        self.assertTrue(second_submission["already_completed"])
        self.assertFalse(second_submission["duplicate_submission"])
        self.assertEqual(second_submission["xp_awarded"], 0)
        self.assertTrue(second_submission["correct"])

        replay_wrong_answer = submit_answer(
            self.player_id,
            str(uuid4()),
            "1.1",
            "B",
        )
        self.assertTrue(replay_wrong_answer["already_completed"])
        self.assertFalse(replay_wrong_answer["duplicate_submission"])
        self.assertFalse(replay_wrong_answer["correct"])
        self.assertEqual(replay_wrong_answer["correct_answer"], "A")
        self.assertEqual(replay_wrong_answer["xp_awarded"], 0)

        progress = get_player_progress(self.player_id)
        self.assertEqual(progress["total_xp"], 100)
        self.assertEqual(progress["rank"]["name"], "Radar Rookie")
        self.assertEqual(progress["completed_task_ids"], ["1.1"])
        journal = get_research_journal(self.player_id)
        self.assertEqual(len(journal["entries"]), 1)
        self.assertTrue(journal["entries"][0]["training_only"])

    def test_incorrect_answer_is_journaled_and_can_be_retried(self):
        incorrect = submit_answer(
            self.player_id,
            str(uuid4()),
            "1.1",
            "B",
        )
        self.assertFalse(incorrect["correct"])
        self.assertEqual(incorrect["xp_awarded"], 0)

        correct = submit_answer(
            self.player_id,
            str(uuid4()),
            "1.1",
            "A",
        )
        self.assertTrue(correct["correct"])
        self.assertEqual(correct["xp_awarded"], 100)
        entries = get_research_journal(self.player_id)["entries"]
        self.assertEqual(len(entries), 2)
        self.assertEqual({entry["correct"] for entry in entries}, {False, True})

    def test_submission_id_cannot_be_reused_for_another_task(self):
        submission_id = str(uuid4())
        submit_answer(self.player_id, submission_id, "1.1", "A")
        with self.assertRaises(SubmissionConflictError):
            submit_answer(self.player_id, submission_id, "1.2", "B")

    def test_challenges_unlock_sequentially_and_locked_tasks_are_rejected(self):
        initial = list_missions()[0]["tasks"]
        self.assertEqual(
            [task["id"] for task in initial if task["unlocked"]],
            ["1.1"],
        )
        with self.assertRaises(TaskLockedError):
            submit_answer(self.player_id, str(uuid4()), "1.2", "B")

        for task_id, answer in (("1.1", "A"), ("1.2", "B")):
            submit_answer(self.player_id, str(uuid4()), task_id, answer)
            completed = get_player_progress(self.player_id)["completed_task_ids"]
            unlocked = [
                task["id"]
                for task in list_missions(completed)[0]["tasks"]
                if task["unlocked"]
            ]
            expected = ["1.1", "1.2"] if task_id == "1.1" else ["1.1", "1.2", "1.3"]
            self.assertEqual(unlocked, expected)

    def test_reset_is_scoped_to_training_database_and_preserves_sar_output(self):
        other_player_id = str(uuid4())
        submit_answer(self.player_id, str(uuid4()), "1.1", "A")
        submit_answer(other_player_id, str(uuid4()), "1.1", "A")

        sar_outputs = Path(self.temporary.name) / "outputs"
        sar_outputs.mkdir()
        sentinel_output = sar_outputs / "new_water.tif"
        sentinel_output.write_bytes(b"synthetic test sentinel; not real SAR")

        progress = reset_player_progress(self.player_id)
        self.assertEqual(progress["total_xp"], 0)
        self.assertEqual(progress["completed_task_ids"], [])
        self.assertEqual(get_research_journal(self.player_id)["entries"], [])
        self.assertEqual(get_player_progress(other_player_id)["total_xp"], 100)
        self.assertEqual(
            sentinel_output.read_bytes(),
            b"synthetic test sentinel; not real SAR",
        )

    def test_api_missions_reflect_player_unlock_progression(self):
        initial = self._request(
            "GET",
            f"/api/gamification/missions?player_id={self.player_id}",
        ).json()["missions"][0]["tasks"]
        self.assertEqual(
            [task["id"] for task in initial if task["unlocked"]],
            ["1.1"],
        )
        submit_answer(self.player_id, str(uuid4()), "1.1", "A")
        updated = self._request(
            "GET",
            f"/api/gamification/missions?player_id={self.player_id}",
        ).json()["missions"][0]["tasks"]
        self.assertEqual(
            [task["id"] for task in updated if task["unlocked"]],
            ["1.1", "1.2"],
        )

    def test_reset_api_is_development_only_and_explicitly_enabled(self):
        submit_answer(self.player_id, str(uuid4()), "1.1", "A")
        reset_url = f"/api/gamification/players/{self.player_id}/reset"

        with patch.dict(
            os.environ,
            {
                "TERRALENS_ENV": "production",
                "TERRALENS_ENABLE_GAMIFICATION_RESET": "true",
            },
        ):
            denied = self._request("POST", reset_url)
            self.assertEqual(denied.status_code, 404)
            self.assertEqual(
                self._request(
                    "GET",
                    f"/api/gamification/players/{self.player_id}/progress",
                ).json()["total_xp"],
                100,
            )

        with patch.dict(
            os.environ,
            {
                "TERRALENS_ENV": "development",
                "TERRALENS_ENABLE_GAMIFICATION_RESET": "true",
            },
        ):
            self.assertEqual(
                self._request("GET", "/api/gamification/config").json(),
                {"development_reset_enabled": True},
            )
            reset = self._request("POST", reset_url)
            self.assertEqual(reset.status_code, 200)
            self.assertTrue(reset.json()["training_only"])
            self.assertEqual(reset.json()["progress"]["total_xp"], 0)
            self.assertEqual(
                self._request(
                    "GET",
                    f"/api/gamification/players/{self.player_id}/journal",
                ).json()["entries"],
                [],
            )

    def test_api_exposes_missions_answers_progress_and_journal(self):
        missions = self._request("GET", "/api/gamification/missions")
        self.assertEqual(missions.status_code, 200)
        mission_payload = json.dumps(missions.json())
        self.assertNotIn("correct_answer", mission_payload)
        self.assertEqual(len(missions.json()["missions"][0]["tasks"]), 4)

        initial_progress = self._request(
            "GET",
            f"/api/gamification/players/{self.player_id}/progress",
        )
        self.assertEqual(initial_progress.status_code, 200)
        self.assertEqual(initial_progress.json()["total_xp"], 0)

        submission_id = str(uuid4())
        answer = self._request(
            "POST",
            f"/api/gamification/players/{self.player_id}/answers",
            json={
                "submission_id": submission_id,
                "task_id": "1.1",
                "answer": "A",
            },
        )
        self.assertEqual(answer.status_code, 200)
        self.assertEqual(answer.json()["xp_awarded"], 100)
        self.assertEqual(answer.json()["correct_answer"], "A")

        progress = self._request(
            "GET",
            f"/api/gamification/players/{self.player_id}/progress",
        )
        self.assertEqual(progress.json()["total_xp"], 100)
        self.assertEqual(progress.json()["missions"][0]["completed_tasks"], 1)

        journal = self._request(
            "GET",
            f"/api/gamification/players/{self.player_id}/journal",
        )
        self.assertEqual(journal.status_code, 200)
        self.assertEqual(len(journal.json()["entries"]), 1)

        locked = self._request(
            "POST",
            f"/api/gamification/players/{self.player_id}/answers",
            json={
                "submission_id": str(uuid4()),
                "task_id": "1.3",
                "answer": "A",
            },
        )
        self.assertEqual(locked.status_code, 409)

    def test_api_rejects_unknown_tasks_and_invalid_player_ids(self):
        unknown_task = self._request(
            "POST",
            f"/api/gamification/players/{self.player_id}/answers",
            json={
                "submission_id": str(uuid4()),
                "task_id": "9.9",
                "answer": "A",
            },
        )
        self.assertEqual(unknown_task.status_code, 404)
        invalid_player = self._request(
            "GET",
            "/api/gamification/players/not-a-uuid/progress",
        )
        self.assertEqual(invalid_player.status_code, 422)

    def test_api_allows_local_post_preflight(self):
        async def send_options() -> httpx.Response:
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport,
                base_url="http://testserver",
            ) as client:
                return await client.options(
                    "/api/gamification/players/"
                    f"{self.player_id}/answers",
                    headers={
                        "Origin": "http://localhost:5173",
                        "Access-Control-Request-Method": "POST",
                        "Access-Control-Request-Headers": "content-type",
                    },
                )

        response = asyncio.run(send_options())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:5173",
        )
        self.assertIn("POST", response.headers["access-control-allow-methods"])

    @staticmethod
    def _request(
        method: str,
        path: str,
        *,
        json: dict[str, str] | None = None,
    ) -> httpx.Response:
        async def send() -> httpx.Response:
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport,
                base_url="http://testserver",
            ) as client:
                return await client.request(method, path, json=json)

        return asyncio.run(send())


if __name__ == "__main__":
    unittest.main()
