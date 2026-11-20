#!/usr/bin/env python3
"""Run: python3 -I .github/scripts/test_superseded_run.py"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("superseded_run", pathlib.Path(__file__).with_name("superseded-run.py"))
superseded_run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(superseded_run)

OLD, NEW = "d" * 40, "2" * 40


def run(id, status="pending"):
    return {"id": id, "status": status, "html_url": f"https://example.invalid/runs/{id}"}


class SupersededTest(unittest.TestCase):
    def test_a_stale_run_with_a_newer_run_waiting_skips(self):
        # #413: run 44797869429 for d1b6a94 held the group while 44824139654 for 21b1b0b waited. Both read "pending".
        runs = [run(44824139654), run(44797869429), run(44794630902, "completed")]
        self.assertEqual(superseded_run.superseded(44797869429, OLD, NEW, runs)["id"], 44824139654)

    def test_the_run_for_mains_head_never_skips(self):
        self.assertIsNone(superseded_run.superseded(44824139654, NEW, NEW, [run(44824139654), run(44900000000)]))

    def test_a_stale_run_with_no_newer_run_waiting_keeps_running(self):
        # Main moved on, but its TestFlight hasn't finished, so nothing would take the group yet.
        runs = [run(44797869429), run(44794630902, "completed"), run(44900000000, "completed")]
        self.assertIsNone(superseded_run.superseded(44797869429, OLD, NEW, runs))

    def test_only_newer_runs_count_since_a_running_run_also_reads_pending(self):
        self.assertIsNone(superseded_run.superseded(44824139654, OLD, NEW, [run(44797869429), run(44824139654)]))

    def test_the_first_newer_waiting_run_is_named(self):
        runs = [run(44900000002, "queued"), run(44900000001), run(44797869429)]
        self.assertEqual(superseded_run.superseded(44797869429, OLD, NEW, runs)["id"], 44900000001)


if __name__ == "__main__":
    unittest.main()
