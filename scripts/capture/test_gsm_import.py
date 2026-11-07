"""Tests for gsm_import.py on synthetic images. No real screenshots.

Run with scripts/import_captures.sh --test.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import gsm_import as gi  # noqa: E402

W, H = 1920, 1080
BAND = 64 / 1080


def scene(seed, blob=None, water=None, band=True):
    """A textured background. blob: (x, y, w, h, count) draws `count`
    bright specks there, like grass. water: (x, y, w, h) gets fresh random
    noise every shot."""
    rng = np.random.default_rng(1)
    base = rng.integers(40, 120, (H, W, 3)).astype(np.float32)
    base = np.asarray(Image.fromarray(base.astype(np.uint8)).resize((W // 8, H // 8)).resize((W, H), Image.BILINEAR),
                      dtype=np.float32)
    shot = np.random.default_rng(seed)
    base += shot.normal(0, 1.0, base.shape)
    if blob:
        x, y, w, h, count = blob
        spots = np.random.default_rng(7)
        for _ in range(count):
            px, py = int(x + spots.random() * (w - 6)), int(y + spots.random() * (h - 12))
            base[py:py + 12, px:px + 4] = (90, 220, 70)
    if water:
        x, y, w, h = water
        base[y:y + h, x:x + w] = shot.integers(20, 200, (h, w, 3))
    if band:
        base[H - 64:] = (13, 15, 33)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))


def grass_set(count_per_level=(20, 120, 400), with_water=True):
    region = (1200, 120, 500, 300)
    water = (60, 650, 500, 300) if with_water else None
    levels = [scene(i, region + (n,), water) for i, n in enumerate(count_per_level)]
    control = scene(9, region + (count_per_level[0],), water)
    return levels, control, region


class LuaReader(unittest.TestCase):
    def test_reads_saved_variables_shape(self):
        text = '''
GraphicsSettingsManagerCaptureDB = {
\t["runs"] = {
\t\t{
\t\t\t["zone"] = "Elwynn Forest, \\"Goldshire\\"",
\t\t\t["band"] = 0.0592592592592593,
\t\t\t["shots"] = {
\t\t\t\t{
\t\t\t\t\t["stamp"] = "110626_201500",
\t\t\t\t\t["actual"] = 16,
\t\t\t\t\t["ok"] = true,
\t\t\t\t}, -- [1]
\t\t\t},
\t\t\t["skipped"] = {
\t\t\t},
\t\t\t["note"] = "line one\\
line two",
\t\t}, -- [1]
\t},
}
Other = nil
'''
        data = gi.parse_lua(text)
        run = data["GraphicsSettingsManagerCaptureDB"]["runs"][0]
        self.assertEqual(run["zone"], 'Elwynn Forest, "Goldshire"')
        self.assertAlmostEqual(run["band"], 0.0592592592592593)
        self.assertEqual(run["shots"][0], {"stamp": "110626_201500", "actual": 16, "ok": True})
        self.assertEqual(run["skipped"], {})
        self.assertEqual(run["note"], "line one\nline two")
        self.assertIsNone(data["Other"])


class Matching(unittest.TestCase):
    def test_nearest_unused_file_saved_just_before_the_log_stamp(self):
        with tempfile.TemporaryDirectory() as d:
            for name in ["WoWScrnShot_110626_201500.jpg", "WoWScrnShot_110626_201502.jpg",
                         "WoWScrnShot_110626_201530.jpg", "WoWScrnShot_110626_201545.jpg", "notes.txt"]:
                Path(d, name).write_bytes(b"")
            shots = [{"stamp": "110626_201501"}, {"stamp": "110626_201502"}, {"stamp": "110626_201510"},
                     {"stamp": "110626_201533"}, {"stamp": "110626_201543"}]
            got = [p.name if p else None for p in gi.match_files(shots, d)]
            self.assertEqual(got, ["WoWScrnShot_110626_201500.jpg", "WoWScrnShot_110626_201502.jpg", None,
                                   "WoWScrnShot_110626_201530.jpg", None])


class FindChange(unittest.TestCase):
    def analyze(self, levels, control):
        return gi.analyze(levels, control, BAND)

    def assert_aspect(self, crop):
        _, _, w, h = crop
        self.assertLessEqual(abs(w / h - gi.ASPECT), 0.02, crop)

    def test_no_focus_box_when_the_change_fills_the_crop(self):
        levels, control, _ = grass_set()
        self.assertIsNone(self.analyze(levels, control)["focus"])

    def test_crop_holds_the_grass_and_ignores_moving_water(self):
        levels, control, (rx, ry, rw, rh) = grass_set()
        result = self.analyze(levels, control)
        x, y, w, h = result["crop"]
        self.assertFalse(result["no_change"])
        self.assert_aspect(result["crop"])
        self.assertGreaterEqual(w, gi.OUT_W, "never narrower than the output, so nothing is upscaled")
        cx, cy = rx + rw / 2, ry + rh / 2
        self.assertTrue(x <= cx <= x + w and y <= cy <= y + h, result["crop"])
        self.assertGreater(x + w, 1300)
        self.assertLess(y, 650, "the crop does not reach the water")
        self.assertGreaterEqual(result["share"], gi.SHARE)

    def test_without_a_control_the_water_pulls_the_crop(self):
        levels, _, _ = grass_set()
        result = self.analyze(levels, None)
        self.assertLess(result["share"], 0.95)

    def test_focus_box_marks_a_small_change_inside_the_crop(self):
        rx, ry, rw, rh = region = (1300, 200, 200, 90)
        levels = [scene(i, region + (n,)) for i, n in enumerate((5, 30, 90))]
        result = self.analyze(levels, scene(9, region + (5,)))
        self.assertIsNotNone(result["focus"])
        x, y, w, h = result["crop"]
        fx, fy, fw, fh = result["focus"]
        mid_x = (x + (fx + fw / 2) * w)
        mid_y = (y + (fy + fh / 2) * h)
        self.assertTrue(rx <= mid_x <= rx + rw and ry <= mid_y <= ry + rh, (mid_x, mid_y))

    def test_identical_shots_report_no_change_and_use_the_whole_frame(self):
        img = scene(0)
        result = self.analyze([img, scene(1), scene(2)], scene(3))
        self.assertTrue(result["no_change"])
        self.assertIsNone(result["focus"])
        self.assert_aspect(result["crop"])
        self.assertGreaterEqual(result["crop"][2], W - 4)

    def test_a_tiny_change_still_gets_the_minimum_width(self):
        region = (900, 400, 40, 40)
        levels = [scene(i, region + (n,), band=True) for i, n in enumerate((1, 5, 20))]
        result = self.analyze(levels, scene(9, region + (1,)))
        self.assertEqual(result["crop"][2], gi.OUT_W)
        self.assert_aspect(result["crop"])

    def test_band_is_cut_off(self):
        levels, control, _ = grass_set()
        result = self.analyze(levels, control)
        self.assertLessEqual(result["worlds"][0].size[1], H - 64)


class PickSets(unittest.TestCase):
    @staticmethod
    def run_of(*sets):
        """sets: (cvar, levels) pairs, logged in that order."""
        return {"shots": [{"cvar": cvar, "shot": lvl, "level": lvl, "stamp": "110626_200000"}
                          for cvar, levels in sets for lvl in levels]}

    def test_newest_complete_set_wins_and_partial_runs_do_not_replace_it(self):
        full = ("low", "medium", "high", "control")
        runs = [
            (1, self.run_of(("groundEffectDist", ("high",)))),
            (2, self.run_of(("groundEffectDist", full), ("groundEffectFade", ("low", "control")))),
            (3, self.run_of(("groundEffectDist", ("high",)), ("reflectionMode", full))),
            (4, self.run_of(("reflectionMode", full))),
        ]
        sets, partial = gi.pick_sets(runs)
        self.assertEqual({cvar: v[0] for cvar, v in sets.items()}, {"groundEffectDist": 2, "reflectionMode": 4})
        self.assertEqual({cvar: v[0] for cvar, v in partial.items()}, {"groundEffectFade": 2})


class EndToEnd(unittest.TestCase):
    def test_import_writes_textures_manifest_and_review(self):
        levels, control, _ = grass_set()
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            screens, repo = d / "Screenshots", d / "repo"
            screens.mkdir()
            (repo / "GraphicsSettingsManager/Media").mkdir(parents=True)
            stamps = ["110626_201500", "110626_201505", "110626_201510", "110626_201515"]
            for img, stamp in zip(levels + [control], stamps):
                img.save(screens / f"WoWScrnShot_{stamp}.jpg", quality=92)
            shots = []
            for (shot, value), stamp in zip([("low", 16), ("medium", 136), ("high", 256), ("control", 16)], stamps):
                level = "low" if shot == "control" else shot
                shots.append(f'{{ ["stamp"] = "{stamp}", ["cvar"] = "groundEffectDensity", ["shot"] = "{shot}", '
                             f'["level"] = "{level}", ["requested"] = {value}, ["actual"] = {value}, ["result"] = "ok" }},')
            log = d / "GraphicsSettingsManager_Capture.lua"
            log.write_text("GraphicsSettingsManagerCaptureDB = { [\"runs\"] = { {\n"
                           '["build"] = "1.60.1.70790", ["zone"] = "Elwynn Forest", ["result"] = "done",\n'
                           f'["started"] = "110626_201455", ["band"] = {BAND},\n'
                           '["labels"] = { ["groundEffectDensity"] = "Grass density" },\n'
                           '["shots"] = {\n' + "\n".join(shots) + "\n}, [\"skipped\"] = {},\n} } }\n")

            self.assertEqual(gi.main(["import", "--log", str(log), "--screens", str(screens), "--repo", str(repo)]), 0)

            for level in gi.LEVELS:
                with Image.open(repo / gi.SHOTS_DIR / f"groundEffectDensity_{level}.tga") as tga:
                    self.assertEqual(tga.size, gi.TEXTURE)
            manifest = json.loads((repo / gi.MANIFEST_JSON).read_text())
            entry = manifest["settings"]["groundEffectDensity"]
            self.assertEqual(entry["values"], {"low": 16, "medium": 136, "high": 256})
            self.assertEqual(entry["coords"][3], 0.71875)
            lua = (repo / gi.MANIFEST_LUA).read_text()
            self.assertIn('note = "Elwynn Forest. Fixed camera, only this setting changed."', lua)
            self.assertIn("Media\\\\Shots\\\\groundEffectDensity_high", lua)
            self.assertIn("values = { low = 16, medium = 136, high = 256 },", lua)
            review = (repo / gi.REVIEW).read_text()
            self.assertIn("Grass density", review)
            self.assertIn("data:image/jpeg;base64,", review)

            # An override moves the crop and turns the focus box off.
            (repo / gi.OVERRIDES_JSON).write_text(json.dumps(
                {"groundEffectDensity": {"crop": [0.5, 0.5, 0.5], "focus": None, "note": "Hand cropped."}}))
            gi.main(["import", "--log", str(log), "--screens", str(screens), "--repo", str(repo)])
            entry = json.loads((repo / gi.MANIFEST_JSON).read_text())["settings"]["groundEffectDensity"]
            self.assertEqual(entry["crop"][2], 960)
            self.assertIsNone(entry["focus"])
            self.assertIn('note = "Hand cropped."', (repo / gi.MANIFEST_LUA).read_text())
            self.assertNotIn("focus =", (repo / gi.MANIFEST_LUA).read_text())

    def test_empty_manifest_matches_the_shipped_file(self):
        self.assertEqual(gi.manifest_lua({"settings": {}}).splitlines()[-1], "ns.Manifest = {}")


if __name__ == "__main__":
    unittest.main()
