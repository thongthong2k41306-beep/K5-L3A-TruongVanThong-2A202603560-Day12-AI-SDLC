"""Black-box contract tests with independent numeric expectations, not model copies.

Every run saves the actual scenario, inputs, JSONL, and process logs in .tools/test-runs.
Only successful real runs become evidence. No third-party Python packages needed.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import manage

T = json.loads((ROOT / "game.contract.json").read_text(encoding="utf-8"))["tuning"]
PROOF = ROOT / "docs/proof/phase-4"
RUNS = ROOT / ".tools/test-runs"
BASE = {"random_motes": False, "random_shades": False, "motes": [], "shades": []}


def events(rows, name):
    return [row for row in rows if row.get("name") == name]


def snapshots(rows):
    return [row for row in rows if row["type"] == "snapshot"]


class ContractTests(unittest.TestCase):
    count = 0
    elapsed = 0.0

    def invoke(self, scenario=None, frames=None, ticks=1, every=1, seed=2026,
               expected_code=0, raw_scenario=None, raw_inputs=None, extra=None, night=1):
        ContractTests.count += 1
        directory = RUNS / f"{self._testMethodName}-{ContractTests.count:03}"
        directory.mkdir(parents=True, exist_ok=True)
        scenario_path, inputs_path, output_path = [directory / name for name in ("scenario.json", "inputs.json", "out.jsonl")]
        args = ["--seed", str(seed), "--night", str(night), "--ticks", str(ticks),
                "--snapshot-every", str(every), "--out", str(output_path)]
        if scenario is not None or raw_scenario is not None:
            scenario_path.write_text(raw_scenario if raw_scenario is not None else json.dumps(scenario), encoding="utf-8")
            args += ["--scenario", str(scenario_path)]
        if frames is not None or raw_inputs is not None:
            inputs_path.write_text(raw_inputs if raw_inputs is not None else json.dumps({"frames": frames}), encoding="utf-8")
            args += ["--inputs", str(inputs_path)]
        if extra:
            args += extra
        started = time.perf_counter()
        result = subprocess.run(manage.command(["--headless", "--script", "res://src/headless.gd", "--", *args]),
                                cwd=ROOT, env=manage.environment(), capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=45)
        ContractTests.elapsed += time.perf_counter() - started
        (directory / "process.log").write_text(result.stdout + result.stderr, encoding="utf-8")
        self.assertEqual(result.returncode, expected_code, result.stdout + result.stderr)
        self.assertNotIn("SCRIPT ERROR", result.stdout + result.stderr)
        self.assertNotIn("Parse Error", result.stdout + result.stderr)
        if expected_code:
            self.assertTrue(result.stderr.strip(), "Errors must be reported on stderr")
            return []
        data = output_path.read_bytes()
        self.assertTrue(data.endswith(b"\n"))
        rows = [json.loads(line) for line in data.splitlines()]
        self.assertEqual(rows[0]["type"], "snapshot")
        self.assertEqual(rows[0]["tick"], 0)
        self.assertEqual(rows[-1]["type"], "end")
        self.assertEqual(sum(row["type"] == "end" for row in rows), 1)
        for row in snapshots(rows):
            self.assertLessEqual(row["sim_tick"], row["tick"])
            self.assertEqual(row["tick"] % every, 0)
            self.assertEqual(len(row["lanterns"]), 4 + night)
            self.assertEqual(row["motes_active"], len(row["motes"]))
            for pos in [row["player"]["pos"], *[x["pos"] for x in row["shades"]], *[x["pos"] for x in row["motes"]]]:
                self.assertTrue(all(abs(float(v) - round(float(v), 3)) < 1e-9 for v in pos))
        self.last_directory = directory
        return rows

    def run_sim(self, patch=None, frames=None, **kwargs):
        scenario = copy.deepcopy(BASE)
        scenario.update(patch or {})
        return self.invoke(scenario, frames, **kwargs)

    def test_tick_zero_and_exact_steps(self):
        rows = self.run_sim(ticks=0)
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0]["player"]["pos"], [0, 0, 0])
        self.assertEqual(rows[-1]["ticks"], 0)
        rows = self.run_sim(ticks=23, every=10)
        self.assertEqual([s["tick"] for s in snapshots(rows)], [0, 10, 20])
        self.assertEqual(rows[-1]["ticks"], 23)
        self.assertAlmostEqual(snapshots(rows)[-1]["time_left_s"], 240 - 20 / 60)

    def test_movement_and_sticky_frames(self):
        rows = self.run_sim(frames=[{"tick": 0, "move": [0, 1]}, {"tick": 30, "move": [0, 0]}], ticks=60)
        self.assertEqual(snapshots(rows)[-1]["player"]["pos"], [0, 0, 3])
        rows = self.run_sim(frames=[{"tick": 0, "move": [1, 0]}, {"tick": 30, "cam_yaw_deg": 90}], ticks=60)
        self.assertEqual(snapshots(rows)[-1]["player"]["pos"], [3, 0, -3])

    def test_diagonal_normalization_and_camera(self):
        rows = self.run_sim(frames=[{"tick": 0, "move": [1, 1]}], ticks=60)
        pos = snapshots(rows)[-1]["player"]["pos"]
        self.assertAlmostEqual(pos[0], T["player_speed"] / 2**0.5, places=3)
        self.assertAlmostEqual(pos[2], T["player_speed"] / 2**0.5, places=3)
        rows = self.run_sim(frames=[{"tick": 0, "move": [0, 1], "cam_yaw_deg": 90}], ticks=60)
        self.assertEqual(snapshots(rows)[-1]["player"]["pos"], [6, 0, 0])

    def test_jump_edges_and_landing(self):
        rows = self.run_sim(frames=[{"tick": 0, "jump": True}], ticks=120)
        self.assertGreater(snapshots(rows)[1]["player"]["pos"][1], 0)
        self.assertEqual(snapshots(rows)[-1]["player"]["pos"][1], 0)
        self.assertEqual(snapshots(rows)[100]["player"]["pos"][1], 0, "Holding jump must not bounce")
        rows = self.run_sim(frames=[{"tick": 0, "jump": True}, {"tick": 80, "jump": False}, {"tick": 90, "jump": True}], ticks=91)
        self.assertGreater(snapshots(rows)[-1]["player"]["pos"][1], 0)

    def test_pickup_radius_xz_and_capacity(self):
        radius = T["pickup_radius"]
        rows = self.run_sim({"player": {"carried": 9}, "motes": [[radius, 99, 0], [0, 0, 0], [radius + 0.01, 0, 0]]})
        self.assertEqual(snapshots(rows)[0]["score"], 0)
        self.assertEqual(snapshots(rows)[0]["player"]["carried"], 9)
        self.assertEqual(snapshots(rows)[-1]["player"]["carried"], 10)
        self.assertEqual(len(events(rows, "mote_picked")), 1)
        self.assertEqual(events(rows, "mote_picked")[0]["tick"], 1)
        self.assertEqual(rows[-1]["score"], 0)

    def test_partial_deposit_and_nearest_lantern(self):
        rows = self.run_sim({"player": {"carried": 4}, "lanterns": [{"id": "L1", "pos": [0, 100, 3]}, {"id": "L2", "pos": [0, 0, 2]}]}, frames=[{"tick": 0, "interact": True}], ticks=30)
        self.assertEqual(len(events(rows, "deposit")), 1)
        self.assertEqual(events(rows, "deposit")[0]["data"], {"lantern_id": "L2", "amount": 4, "deposited": 4})
        self.assertFalse(snapshots(rows)[-1]["lanterns"][1]["lit"])

    def test_interact_edge_and_exact_radius(self):
        patch = {"player": {"carried": 10}, "lanterns": [{"id": "L1", "pos": [0, 0, T["interact_radius"]]}, {"id": "L2", "pos": [0, 0, 2]}]}
        rows = self.run_sim(patch, frames=[{"tick": 0, "interact": True}], ticks=20)
        self.assertEqual(len(events(rows, "deposit")), 1)
        self.assertEqual(events(rows, "deposit")[0]["data"]["lantern_id"], "L2")
        patch["lanterns"] = [{"id": "L1", "pos": [0, 0, T["interact_radius"]]}]
        rows = self.run_sim(patch, frames=[{"tick": 0, "interact": True}])
        self.assertEqual(len(events(rows, "lantern_lit")), 1)
        patch["lanterns"][0]["pos"][2] += 0.01
        rows = self.run_sim(patch, frames=[{"tick": 0, "interact": True}])
        self.assertEqual(len(events(rows, "deposit")), 0)

    def test_winning_and_score(self):
        scenario = json.loads((ROOT / "tests/scenarios/dawn_win.json").read_text())
        rows = self.invoke(scenario, [{"tick": 0, "interact": True}], ticks=600)
        self.assertEqual(rows[-1], {"type": "end", "ticks": 1, "state": "won", "score": 1046})
        self.assertEqual([e["name"] for e in rows if e["type"] == "event"], ["night_start", "deposit", "lantern_lit", "game_over"])
        self.assertEqual(events(rows, "game_over")[0]["data"], {"result": "won", "reason": "dawn_survived"})
        self.assertEqual(events(rows, "lantern_lit")[0]["data"], {"lantern_id": "L1", "relight": False})
        self.assertEqual(snapshots(rows)[0]["score"], 0, "Preset lit lanterns must not score")
        PROOF.mkdir(parents=True, exist_ok=True)
        (PROOF / "win.jsonl").write_bytes((self.last_directory / "out.jsonl").read_bytes())

    def test_pulse_radius_push_stun_and_cost(self):
        radius = T["pulse_radius"]
        rows = self.run_sim({"player": {"carried": 10}, "shades": [{"id": "near", "pos": [radius, 9, 0]}, {"id": "far", "pos": [radius + 0.01, 0, 0]}]}, [{"tick": 0, "pulse": True}])
        self.assertEqual(events(rows, "pulse")[0]["data"]["stunned_ids"], ["near"])
        last = snapshots(rows)[-1]
        self.assertEqual(last["player"]["carried"], 7)
        near = next(shade for shade in last["shades"] if shade["id"] == "near")
        self.assertEqual(near["pos"], [9, 9, 0])
        self.assertEqual(near["state"], "stunned")
        self.assertEqual(rows[-1]["score"], T["score"]["per_stun"])
        rows = self.run_sim({"player": {"carried": 2}}, [{"tick": 0, "pulse": True}])
        self.assertEqual(len(events(rows, "pulse")), 0)
        self.assertEqual(snapshots(rows)[-1]["player"]["carried"], 2)

    def test_stun_expires_at_declared_tick(self):
        rows = self.run_sim({"player": {"carried": 3}, "shades": [{"pos": [6, 0, 0]}]}, [{"tick": 0, "pulse": True}], ticks=121)
        ss = snapshots(rows)
        self.assertEqual(ss[120]["shades"][0]["state"], "stunned")
        self.assertEqual(ss[121]["shades"][0]["state"], "wander")

    def test_pulse_cooldown_and_rising_edge(self):
        frames = [{"tick": 0, "pulse": True}, {"tick": 1, "pulse": False}, {"tick": 2, "pulse": True},
                  {"tick": 179, "pulse": False}, {"tick": 180, "pulse": True}]
        rows = self.run_sim({"player": {"carried": 9}}, frames, ticks=181)
        self.assertEqual([e["tick"] for e in events(rows, "pulse")], [1, 181])
        self.assertEqual(snapshots(rows)[-1]["player"]["carried"], 3)

    def test_damage_drop_invulnerability_and_loss(self):
        rows = self.run_sim({"player": {"carried": 10}, "shades": [{"pos": [0, 0, 0]}]}, ticks=500)
        hits = events(rows, "player_hit")
        self.assertEqual([e["tick"] for e in hits], [1, 91, 181])
        self.assertEqual([e["data"]["dropped"] for e in hits], [2, 2, 1])
        self.assertEqual(rows[-1]["state"], "lost")
        self.assertEqual(rows[-1]["ticks"], 181)
        self.assertEqual(events(rows, "game_over")[0]["data"]["reason"], "no_flames")

    def test_safe_lantern_stops_chase(self):
        rows = self.run_sim({"lanterns": [{"id": "L1", "pos": [0, 0, 0], "lit": True}], "shades": [{"pos": [10, 0, 0]}]}, ticks=240)
        last = snapshots(rows)[-1]
        self.assertEqual(last["shades"][0]["pos"], [T["safe_radius"], 0, 0])
        self.assertEqual(last["player"]["flames"], 3)
        self.assertEqual(events(rows, "player_hit"), [])

    def test_dawn_loss(self):
        rows = self.run_sim({"time_left_s": 1}, ticks=200)
        self.assertEqual(rows[-1]["ticks"], 60)
        self.assertEqual(events(rows, "game_over")[0]["data"], {"result": "lost", "reason": "dawn"})
        self.assertEqual(snapshots(rows)[-1]["time_left_s"], 0)

    def test_boundary_fall_and_respawn(self):
        rows = self.run_sim(frames=[{"tick": 0, "move": [1, 0]}], ticks=600, every=60)
        self.assertEqual(events(rows, "player_hit")[0]["data"]["by"], "fall")
        self.assertEqual(snapshots(rows)[-1]["player"]["flames"], 2)

    def test_false_random_flags_and_supplied_ids(self):
        rows = self.run_sim(ticks=1200, every=600)
        self.assertEqual(snapshots(rows)[-1]["motes_active"], 0)
        self.assertEqual(snapshots(rows)[-1]["shades"], [])
        self.assertEqual(events(rows, "shade_spawned"), [])
        rows = self.run_sim({"shades": [{"pos": [30, 0, 0]}, {"id": "S1", "pos": [30, 0, 1]}]}, ticks=0)
        ids = [s["id"] for s in rows[0]["shades"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertIn("S1", ids)

    def test_seeded_default_generation_is_deterministic(self):
        self.invoke(ticks=300, every=10)
        first = (self.last_directory / "out.jsonl").read_bytes()
        self.invoke(ticks=300, every=10)
        second = (self.last_directory / "out.jsonl").read_bytes()
        self.assertEqual(first, second)
        self.invoke(ticks=300, every=10, seed=2027)
        self.assertNotEqual(first, (self.last_directory / "out.jsonl").read_bytes())
        PROOF.mkdir(parents=True, exist_ok=True)
        (PROOF / "determinism.json").write_text(json.dumps({"seed": 2026, "ticks": 300,
            "sha256_run_1": hashlib.sha256(first).hexdigest(), "sha256_run_2": hashlib.sha256(second).hexdigest(),
            "bytes_equal": True}, indent=2), encoding="utf-8")

    def test_random_spawn_event(self):
        rows = self.run_sim({"random_shades": True, "lanterns": [{"id": "L1", "pos": [0, 0, 0], "lit": True}]}, ticks=600, every=600)
        self.assertEqual([e["tick"] for e in events(rows, "shade_spawned")], [300, 300])

    def test_full_default_night_replay(self):
        result = subprocess.run(manage.command(["--headless", "--script", "res://tests/autoplay.gd"]),
                                cwd=ROOT, env=manage.environment(), capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=45)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("SCRIPT ERROR", result.stdout + result.stderr)
        frames = json.loads((PROOF / "autoplay-inputs.json").read_text())["frames"]
        rows = self.invoke(frames=frames, ticks=18000, every=60)
        self.assertIn(rows[-1]["state"], ("won", "lost"))
        self.assertGreater(len(events(rows, "lantern_lit")), 0)
        expected = json.loads((PROOF / "autoplay-report.json").read_text())
        self.assertEqual(rows[-1]["ticks"], expected["ticks"])
        self.assertEqual(rows[-1]["score"], expected["score"])
        self.assertEqual(rows[-1]["state"], expected["state"])
        (PROOF / "autoplay.jsonl").write_bytes((self.last_directory / "out.jsonl").read_bytes())

    def test_all_malformed_fixtures_exit_two(self):
        bad_scenarios = ["{", "[]", '{"player":{"pos":[1,2]}}', '{"random_motes":0}',
                         '{"shades":[{"pos":[0,0,0],"id":"x"},{"pos":[0,0,1],"id":"x"}]}',
                         '{"lanterns":[{"id":"L6"}]}', '{"player":{"carried":31}}',
                         '{"motes":[[0,"bad",0]]}', '{"time_left_s":-1}']
        for raw in bad_scenarios:
            with self.subTest(scenario=raw):
                self.invoke(raw_scenario=raw, expected_code=2)
        bad_inputs = ['{"frames":[{"tick":0},{"tick":0}]}', '{"frames":[{"tick":2},{"tick":1}]}',
                      '{"frames":[{"tick":0,"move":[2,0]}]}', '{"frames":[{"tick":0,"pulse":1}]}',
                      '{"frames":[{"tick":0.5}]}', '{"frames":null}', '{"frames":[{"tick":-1}]}']
        for raw in bad_inputs:
            with self.subTest(inputs=raw):
                self.invoke(raw_inputs=raw, expected_code=2)

    def test_bad_cli_exit_two(self):
        self.invoke(BASE, expected_code=2, extra=["--night", "4"])
        self.invoke(BASE, expected_code=2, extra=["--snapshot-every", "0"])

    def test_phase2_pause_freezes_timers_and_spawn(self):
        rows = self.run_sim({"player": {"pulse_cd_ticks": 60, "invuln_ticks": 60}},
            [{"tick": 0, "pause": True, "move": [0, 1]}, {"tick": 5, "pause": False},
             {"tick": 90, "pause": True}], ticks=92)
        ss = snapshots(rows)
        self.assertEqual(ss[90]["state"], "paused")
        self.assertEqual(ss[90]["sim_tick"], 0)
        self.assertEqual(ss[90]["time_left_s"], ss[0]["time_left_s"])
        self.assertEqual(ss[90]["player"], ss[0]["player"])
        self.assertEqual(ss[91]["sim_tick"], 1)
        self.assertEqual([events(rows, name)[0]["tick"] for name in ("paused", "resumed")], [1, 91])

    def test_phase2_dash_charm_duration_and_respawn(self):
        rows = self.run_sim({"charms": [{"id": "C1", "pos": [0, 0, 0]}]},
            [{"tick": 1, "dash": True}, {"tick": 2, "dash": False},
             {"tick": 5, "dash": True}, {"tick": 6, "dash": False},
             {"tick": 13, "dash": True}], ticks=15, night=2)
        ss = snapshots(rows)
        self.assertEqual(events(rows, "charm_picked")[0]["data"], {"charm_id": "C1", "charm_ticks": 600})
        self.assertEqual([event["tick"] for event in events(rows, "dash")], [2, 14])
        self.assertEqual(ss[2]["player"]["vel"], [0, 0, 14])
        self.assertEqual(ss[2]["player"]["dash_cd_s"], 0)
        self.assertEqual(ss[1]["charms"][0]["respawn_s"], 45)
        rows = self.run_sim({"player": {"charm_ticks": 2}},
            [{"tick": 0, "move": [0, 1]}], ticks=2, night=2)
        self.assertEqual(snapshots(rows)[1]["player"]["vel"], [0, 0, 7.2])
        self.assertEqual(snapshots(rows)[2]["player"]["vel"], [0, 0, 6])

    def test_phase2_drifter_steals_before_hit_and_drops(self):
        rows = self.run_sim({"player": {"carried": 10, "invuln_ticks": 30},
            "drifters": [{"id": "D1", "pos": [1, 0, 0]}], "shades": [{"pos": [0, 0, 0]}]},
            [{"tick": 1, "pulse": True}], ticks=4, night=2)
        self.assertEqual(events(rows, "drifter_steal")[0]["data"], {"drifter_id": "D1", "amount": 3, "carried": 7})
        self.assertEqual(events(rows, "drifter_drop")[0]["data"]["amount"], 3)
        self.assertEqual(events(rows, "player_hit"), [])
        self.assertEqual([m["kind"] for m in snapshots(rows)[2]["motes"]], ["dropped"] * 3)
        rows = self.run_sim({"player": {"carried": 10}, "drifters": [{"pos": [1, 0, 0]}],
            "shades": [{"pos": [0, 0, 0]}]}, ticks=1, night=2)
        self.assertLess(rows.index(events(rows, "drifter_steal")[0]), rows.index(events(rows, "player_hit")[0]))

    def test_phase2_three_maps_and_jump_pads(self):
        rows = self.run_sim({"player": {"pos": [20, 0, 18]}}, ticks=90, night=2)
        self.assertEqual(snapshots(rows)[0]["lanterns"][-1]["pos"], [53, 0, -10])
        final = snapshots(rows)[-1]["player"]
        self.assertTrue(final["grounded"])
        self.assertGreater(final["pos"][0], 50)
        rows = self.run_sim({"player": {"pos": [0, 3, 13]}}, ticks=90, night=3)
        self.assertEqual(snapshots(rows)[0]["lanterns"][0]["pos"], [0, 6, 6])
        self.assertEqual(snapshots(rows)[-1]["player"]["pos"][1], 6)
        self.assertTrue(snapshots(rows)[-1]["player"]["grounded"])

    def test_phase2_wind_and_drifter_spawn(self):
        rows = self.run_sim(ticks=2100, every=300, night=3)
        ss = {row["tick"]: row for row in snapshots(rows)}
        self.assertFalse(ss[1500]["wind"]["active"])
        self.assertEqual(len(ss[1200]["drifters"]), 1)
        self.assertTrue(ss[1800]["wind"]["active"])
        self.assertFalse(ss[2100]["wind"]["active"])
        self.assertNotEqual(ss[2100]["player"]["pos"], ss[1500]["player"]["pos"])
        disabled = self.run_sim({"wind_enabled": False, "random_drifters": False}, ticks=2100, every=300, night=3)
        self.assertEqual(snapshots(disabled)[-1]["player"]["pos"], [0, 0, 0])
        self.assertEqual(snapshots(disabled)[-1]["drifters"], [])

    def test_phase2_full_night_headless_budget(self):
        fixture = {"wind_enabled": False, "player": {"invuln_ticks": 18001}}
        started = time.perf_counter()
        rows = self.invoke(fixture, ticks=18000, every=10, night=3)
        elapsed = time.perf_counter() - started
        self.assertEqual(rows[-1]["ticks"], 18000)
        self.assertEqual(events(rows, "game_over")[0]["data"]["reason"], "dawn")
        self.assertLessEqual(elapsed, 30)
        (PROOF / "headless-performance.json").write_text(json.dumps(
            {"night": 3, "ticks": 18000, "seconds": elapsed, "platform": platform.platform(),
             "snapshot_every": 10, "fixture": fixture},
            indent=2), encoding="utf-8")

    def test_phase3_last_tick_threshold_and_no_early_win(self):
        lit = [{"id": f"L{i}", "lit": True} for i in range(1, 6)]
        rows = self.run_sim({"lanterns": lit, "time_left_s": 1}, ticks=80, every=20)
        self.assertEqual([row["state"] for row in snapshots(rows)], ["playing"] * 3 + ["won"])
        self.assertEqual(rows[-1]["ticks"], 60)
        self.assertEqual(rows[-1]["score"], 5 * 149 + 150)
        for night, threshold in [(1, 3), (2, 4), (3, 5)]:
            for count in [threshold - 1, threshold]:
                with self.subTest(night=night, count=count):
                    rows = self.run_sim({"lanterns": lit[:count], "time_left_s": 0.01}, night=night)
                    self.assertEqual(rows[-1]["state"], "won" if count == threshold else "lost")
        rows = self.run_sim({"lanterns": lit[:3], "time_left_s": 0.01,
                             "player": {"flames": 1}, "shades": [{"pos": [0, 0, 0]}]})
        self.assertEqual(events(rows, "game_over")[0]["data"]["reason"], "no_flames")
        self.assertEqual(rows[-1]["score"], 0)

    def test_phase3_decay_extinguish_relight_and_capacity(self):
        patch = {"player": {"carried": 5, "successful_lights": 4}, "motes": [[12, 0, 0]],
                 "lanterns": [{"id": "L1", "pos": [0, 0, 0], "lit": True, "fuel": 1}]}
        rows = self.run_sim(patch, [{"tick": 59, "interact": True}], ticks=61)
        ss = snapshots(rows)
        self.assertEqual(ss[0]["player"]["capacity"], 18)
        self.assertTrue(ss[59]["lanterns"][0]["lit"])
        self.assertEqual(events(rows, "lantern_out")[0]["tick"], 60)
        self.assertEqual(events(rows, "lantern_lit")[0]["data"], {"lantern_id": "L1", "relight": True})
        self.assertEqual(ss[60]["lanterns"][0]["fuel"], 100)
        self.assertEqual(ss[60]["lanterns"][0]["relit_count"], 1)
        self.assertEqual(ss[60]["player"]["capacity"], 20)
        self.assertEqual(rows[-1]["score"], 65)
        rows = self.run_sim({"lanterns": [{"id": "L1", "lit": True, "fuel": 1}]}, ticks=60)
        lamp = snapshots(rows)[-1]["lanterns"][0]
        self.assertEqual((lamp["lit"], lamp["fuel"], lamp["deposited"], lamp["ever_lit"]), (False, 0, 0, True))

    def test_phase3_refuel_rounding_tie_and_repulsion(self):
        patch = {"player": {"carried": 2}, "lanterns": [
            {"id": "L2", "pos": [-1, 0, 0]}, {"id": "L1", "pos": [1, 0, 0], "lit": True, "fuel": 29}],
            "shades": [{"pos": [1, 0, 0], "state": "drain", "target_lantern_id": "L1"}]}
        rows = self.run_sim(patch, [{"tick": 0, "interact": True}], ticks=30)
        self.assertEqual(events(rows, "refuel")[0]["data"], {"lantern_id": "L1", "amount": 2, "fuel": 48.9})
        self.assertFalse(events(rows, "player_hit"))
        self.assertEqual(snapshots(rows)[-1]["shades"][0]["pos"], [7, 0, 0])
        self.assertEqual(rows[-1]["score"], 10)
        rows = self.run_sim({"player": {"carried": 3}, "lanterns": [
            {"id": "L1", "pos": [0, 0, 0], "lit": True, "fuel": 98}]},
            [{"tick": 0, "interact": True}], ticks=1)
        self.assertEqual(events(rows, "refuel")[0]["data"], {"lantern_id": "L1", "amount": 1, "fuel": 100})

    def test_phase3_drain_sums_and_pulse_bonus(self):
        lamp = {"id": "L1", "pos": [0, 0, 0], "lit": True, "fuel": 29}
        pair = [{"id": f"S{i}", "pos": [i, 0, 0], "state": "drain", "target_lantern_id": "L1"}
                for i in [1, 2]]
        rows = self.run_sim({"player": {"pos": [12, 0, 0]}, "lanterns": [lamp], "shades": pair},
                            ticks=120, every=60)
        self.assertEqual([row["data"]["fuel"] for row in events(rows, "fuel_drain")], [18, 18, 7, 7])
        self.assertEqual([row["tick"] for row in events(rows, "fuel_drain")], [60, 60, 120, 120])
        (PROOF / "drain.jsonl").write_bytes((self.last_directory / "out.jsonl").read_bytes())
        rows = self.run_sim({"player": {"carried": 3}, "lanterns": [lamp], "shades": pair},
                            [{"tick": 0, "pulse": True}], ticks=2)
        self.assertEqual(rows[-1]["score"], 30)
        self.assertEqual(snapshots(rows)[-1]["shades"][0]["state"], "stunned")

    def test_phase3_wander_targets_weak_lamp_but_chase_does_not(self):
        rows = self.run_sim({"player": {"pos": [15, 0, 0]}, "lanterns": [
            {"id": "L1", "pos": [0, 0, 2], "lit": True, "fuel": 29},
            {"id": "L2", "pos": [0, 0, -2], "lit": True, "fuel": 29}],
            "shades": [{"id": "S1", "pos": [0, 0, 0], "state": "wander"},
                       {"id": "S2", "pos": [0, 0, 0], "state": "chase"}]}, ticks=2)
        ss = snapshots(rows)[-1]
        self.assertEqual(ss["shades"][0]["state"], "drain")
        self.assertEqual(ss["shades"][1]["state"], "chase")
        self.assertGreater(ss["lanterns"][1]["fuel"], ss["lanterns"][0]["fuel"])


if __name__ == "__main__":
    PROOF.mkdir(parents=True, exist_ok=True)
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ContractTests)
    started = time.perf_counter()
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    report = {"tests": result.testsRun, "passed": result.testsRun - len(result.failures) - len(result.errors),
              "failures": len(result.failures), "errors": len(result.errors), "headless_invocations": ContractTests.count,
              "wall_seconds": round(time.perf_counter() - started, 3),
              "process_wall_seconds": round(ContractTests.elapsed, 3), "platform": platform.platform(),
              "python": platform.python_version(), "godot": str(manage.engine().name),
              "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in sorted((ROOT / "src").glob("*.gd"))},
              "failures_detail": [(str(test), detail) for test, detail in result.failures + result.errors]}
    (PROOF / "test-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    raise SystemExit(0 if result.wasSuccessful() else 1)
