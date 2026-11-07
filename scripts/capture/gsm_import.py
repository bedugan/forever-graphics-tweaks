#!/usr/bin/env python3
"""Turns /gsmcap screenshots into the comparison images GSM ships.

Run through scripts/import_captures.sh, which stages the inputs and runs
this in a container. See docs/GRAPHICS_ASSETS.md.

  gsm_import.py dates    --log FILE [--run N]
  gsm_import.py import   --log FILE --screens DIR --repo DIR [--run N] [--only a,b]
  gsm_import.py manifest --repo DIR

For each setting it finds the area that changes between Low, Medium, and
High, ignores what also moved between the two Low shots (water, weather,
swaying grass), and picks the smallest window with the panel's aspect ratio
that holds most of the change. The same crop applies to every level.
"""
import argparse
import base64
import io
import json
import math
import re
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

# The comparison panel's image area in UI/Comparison.lua is 390 x 140.
PANEL = (390, 140)
ASPECT = PANEL[0] / PANEL[1]
OUT_W = 512
OUT_H = round(OUT_W / ASPECT)
TEXTURE = (512, 256)
COORDS = [0, 1, 0, OUT_H / TEXTURE[1]]
LEVELS = ("low", "medium", "high")
# Share of the change the crop must hold.
SHARE = 0.7
MATCH_SECONDS = 2
ANALYSIS_WIDTH = 480
# Per-pixel difference, out of 255, treated as compression noise.
FLOOR = 3.0
# Used when a run did not record the band height.
DEFAULT_BAND = 0.07
MEDIA = "Interface\\AddOns\\GraphicsSettingsManager\\Media\\Shots\\"

MANIFEST_JSON = "assets/screenshots.json"
OVERRIDES_JSON = "assets/screenshots-overrides.json"
MANIFEST_LUA = "GraphicsSettingsManager/Media/Manifest.lua"
SHOTS_DIR = "GraphicsSettingsManager/Media/Shots"
REVIEW = ".capture/review.html"


# ----- SavedVariables reader --------------------------------------------

TOKEN = re.compile(
    r"""(?P<skip>\s+|--\[\[.*?\]\]|--[^\n]*)
      | (?P<string>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')
      | (?P<number>-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?))
      | (?P<name>[A-Za-z_]\w*)
      | (?P<punct>[{}\[\]=,;])""",
    re.S | re.X,
)
ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
           "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def unescape(body):
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        nxt = body[i + 1]
        if nxt.isdigit():
            digits = re.match(r"\d{1,3}", body[i + 1:]).group()
            out.append(chr(int(digits)))
            i += 1 + len(digits)
        else:
            out.append(ESCAPES.get(nxt, nxt))
            i += 2
    return "".join(out)


def tokenize(text):
    pos, tokens = 0, []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError(f"cannot read SavedVariables near: {text[pos:pos + 30]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind == "skip":
            continue
        value = m.group()
        if kind == "string":
            value = unescape(value[1:-1])
        elif kind == "number":
            value = int(value, 16) if "x" in value.lower() else (
                float(value) if re.search(r"[.eE]", value) else int(value))
        tokens.append((kind, value))
    return tokens


def parse_lua(text):
    """Reads `Name = value` assignments from a SavedVariables file."""
    tokens = tokenize(text)
    pos = 0

    def peek(offset=0):
        return tokens[pos + offset] if pos + offset < len(tokens) else (None, None)

    def take(expected=None):
        nonlocal pos
        tok = tokens[pos]
        if expected is not None and tok[1] != expected:
            raise ValueError(f"expected {expected!r}, got {tok[1]!r}")
        pos += 1
        return tok

    def value():
        kind, v = take()
        if v == "{" and kind == "punct":
            return table()
        if kind in ("string", "number"):
            return v
        if kind == "name" and v in ("true", "false", "nil"):
            return {"true": True, "false": False, "nil": None}[v]
        raise ValueError(f"unexpected {v!r}")

    def table():
        items, n = {}, 0
        while peek()[1] != "}":
            kind, v = peek()
            if v == "[" and kind == "punct":
                take()
                key = value()
                take("]")
                take("=")
            elif kind == "name" and peek(1)[1] == "=":
                take()
                take()
                key = v
            else:
                n += 1
                key = n
            items[key] = value()
            if peek()[1] in (",", ";"):
                take()
        take("}")
        if items and set(items) == set(range(1, len(items) + 1)):
            return [items[i] for i in range(1, len(items) + 1)]
        return items

    out = {}
    while pos < len(tokens):
        _, name = take()
        take("=")
        out[name] = value()
    return out


def load_log(path):
    data = parse_lua(Path(path).read_text(encoding="utf-8", errors="replace"))
    db = data.get("GraphicsSettingsManagerCaptureDB") or {}
    runs = db.get("runs") or []
    if isinstance(runs, dict):
        runs = [runs[k] for k in sorted(runs)]
    return runs


def pick_run(runs, number):
    if not runs:
        raise SystemExit("The capture log has no runs. Did you /reload after capturing?")
    if number is None:
        return len(runs), runs[-1]
    if not 1 <= number <= len(runs):
        raise SystemExit(f"Run {number} does not exist. The log has {len(runs)}.")
    return number, runs[number - 1]


def listify(value):
    if isinstance(value, dict):
        return [value[k] for k in sorted(value)]
    return value or []


# ----- Matching log entries to files ------------------------------------

SHOT_FILE = re.compile(r"^WoWScrnShot_(\d{6}_\d{6})(?:_\d+)?\.(?:jpe?g|png|tga)$", re.I)


def stamp_time(stamp):
    return datetime.strptime(stamp, "%m%d%y_%H%M%S")


def match_files(shots, folder):
    """Pairs each logged shot with the nearest unused screenshot within
    MATCH_SECONDS. Returns a list of paths, or None where nothing matched."""
    files = []
    for path in sorted(Path(folder).iterdir()):
        m = SHOT_FILE.match(path.name)
        if m:
            files.append((stamp_time(m.group(1)), path))
    used, out = set(), []
    for shot in shots:
        when = stamp_time(shot["stamp"])
        best = None
        for i, (t, path) in enumerate(files):
            gap = abs((t - when).total_seconds())
            if i not in used and gap <= MATCH_SECONDS and (best is None or gap < best[0]):
                best = (gap, i)
        if best is None:
            out.append(None)
        else:
            used.add(best[1])
            out.append(files[best[1]][1])
    return out


# ----- Finding the change -----------------------------------------------

def world(img, band):
    """The image above the caption band."""
    w, h = img.size
    cut = min(h - 1, math.ceil(h * band) + 2)
    return img.crop((0, 0, w, h - cut))


def small(img, scale):
    w, h = img.size
    return np.asarray(img.resize((max(1, round(w / scale)), max(1, round(h / scale))), Image.BOX),
                      dtype=np.float32)


def diff(a, b):
    return np.abs(a - b).mean(axis=2)


def blur(x, r):
    """Box blur with radius r, same shape as x."""
    k = 2 * r + 1
    p = np.pad(x, r, mode="edge")
    c = np.cumsum(p, axis=0)
    c = np.vstack([np.zeros((1, c.shape[1]), c.dtype), c])
    rows = (c[k:] - c[:-k]) / k
    c = np.cumsum(rows, axis=1)
    c = np.hstack([np.zeros((c.shape[0], 1), c.dtype), c])
    return (c[:, k:] - c[:, :-k]) / k


def dilate(x, r):
    """Max filter with radius r, so moving things cover where they moved."""
    out = x.copy()
    for d in range(1, r + 1):
        out[d:] = np.maximum(out[d:], x[:-d])
        out[:-d] = np.maximum(out[:-d], x[d:])
    y = out.copy()
    for d in range(1, r + 1):
        y[:, d:] = np.maximum(y[:, d:], out[:, :-d])
        y[:, :-d] = np.maximum(y[:, :-d], out[:, d:])
    return y


def signal_map(levels, control):
    """Per-pixel change between levels, minus what moved on its own."""
    low, medium, high = levels
    change = np.maximum.reduce([diff(low, medium), diff(medium, high), diff(low, high)])
    r = max(1, round(change.shape[1] * 0.01))
    sig = blur(change, r)
    if control is not None:
        sig = sig - 2 * dilate(blur(diff(low, control), r), 2 * r)
    return np.clip(sig - FLOOR, 0, None)


def best_window(sig, min_width):
    """Smallest window at the panel's aspect ratio holding SHARE of the
    signal, at least min_width wide. Returns (x, y, w, h), share."""
    h, w = sig.shape
    total = float(sig.sum())
    integral = np.zeros((h + 1, w + 1), np.float64)
    integral[1:, 1:] = sig.cumsum(0).cumsum(1)
    max_width = min(w, h * ASPECT)
    min_width = min(min_width, max_width)
    best = None
    for width in np.linspace(min_width, max_width, 40):
        wi = min(w, max(1, round(width)))
        hi = min(h, max(1, round(width / ASPECT)))
        sums = (integral[hi:, wi:] - integral[:-hi, wi:]
                - integral[hi:, :-wi] + integral[:-hi, :-wi])
        y, x = np.unravel_index(int(np.argmax(sums)), sums.shape)
        share = float(sums[y, x]) / total if total > 0 else 0
        best = ((int(x), int(y), wi, hi), share)
        if share >= SHARE:
            break
    return best


def centered_window(w, h):
    width = min(w, h * ASPECT)
    height = width / ASPECT
    return ((w - width) / 2, (h - height) / 2, width, height)


def to_full(rect, scale, size):
    """Analysis rect to source pixels, keeping the aspect ratio exact and
    the rect inside the image."""
    W, H = size
    x, y, w, _ = rect
    width = max(min(OUT_W, W), round(w * scale))
    height = round(width / ASPECT)
    if height > H:
        height = H
        width = round(height * ASPECT)
    width = min(width, W)
    cx = (x + rect[2] / 2) * scale
    cy = (y + rect[3] / 2) * scale
    left = int(min(max(0, round(cx - width / 2)), W - width))
    top = int(min(max(0, round(cy - height / 2)), H - height))
    return (left, top, int(width), int(height))


def focus_box(sig, rect):
    """Box around the middle 80% of the change inside rect, as fractions of
    rect from its top-left. None when it would cover most of the image."""
    x, y, w, h = rect
    sub = sig[y:y + h, x:x + w]
    if sub.sum() <= 0:
        return None

    def span(mass, size):
        c = np.cumsum(mass) / mass.sum()
        lo = int(np.searchsorted(c, 0.1))
        hi = int(np.searchsorted(c, 0.9)) + 1
        pad = max(1, round(size * 0.04))
        return max(0, lo - pad), min(size, hi + pad)

    x0, x1 = span(sub.sum(0), w)
    y0, y1 = span(sub.sum(1), h)
    box = [x0 / w, y0 / h, (x1 - x0) / w, (y1 - y0) / h]
    if box[2] * box[3] > 0.6:
        return None
    return [round(v, 4) for v in box]


def analyze(images, control, band):
    """images: Low, Medium, High PIL images. Returns the crop in source
    pixels of the world area, the focus box, and stats."""
    worlds = [world(img, band) for img in images]
    ctrl = world(control, band) if control is not None else None
    size = worlds[0].size
    scale = max(1.0, size[0] / ANALYSIS_WIDTH)
    sig = signal_map([small(img, scale) for img in worlds],
                     small(ctrl, scale) if ctrl is not None else None)
    h, w = sig.shape
    no_change = float((sig > 1).mean()) < 0.001
    if no_change:
        rect, share = centered_window(w, h), 0.0
    else:
        rect, share = best_window(sig, OUT_W / scale)
    crop = to_full(rect, scale, size)
    small_crop = tuple(int(round(v / scale)) for v in crop)
    focus = None if no_change else focus_box(sig, small_crop)
    return {
        "crop": list(crop), "focus": focus, "share": round(share, 3),
        "no_change": no_change, "worlds": worlds, "control": ctrl,
        "signal": sig, "scale": scale,
    }


def apply_override(result, override):
    """crop: [center x, center y, width] as fractions of the world area.
    focus: [x, y, w, h] as fractions of the crop, or null for no box."""
    W, H = result["worlds"][0].size
    if "crop" in override:
        cx, cy, fw = override["crop"]
        width = fw * W
        rect = (cx * W - width / 2, cy * H - width / ASPECT / 2, width, width / ASPECT)
        result["crop"] = list(to_full(rect, 1, (W, H)))
        scale, sig = result["scale"], result["signal"]
        small_crop = tuple(int(round(v / scale)) for v in result["crop"])
        x, y, w, h = small_crop
        total = float(sig.sum())
        result["share"] = round(float(sig[y:y + h, x:x + w].sum()) / total, 3) if total > 0 else 0.0
        result["focus"] = focus_box(sig, small_crop)
    if "focus" in override:
        result["focus"] = override["focus"]


def load_rgb(path):
    with Image.open(path) as img:
        return img.convert("RGB")


def render(img, crop):
    x, y, w, h = crop
    out = Image.new("RGB", TEXTURE, (0, 0, 0))
    out.paste(img.crop((x, y, x + w, y + h)).resize((OUT_W, OUT_H), Image.LANCZOS), (0, 0))
    return out


# ----- Manifest ---------------------------------------------------------

def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lua_number(n):
    return str(int(n)) if float(n).is_integer() else repr(round(float(n), 6))


def manifest_lua(manifest):
    lines = [
        "-- Generated by scripts/import_captures.sh from assets/screenshots.json.",
        "-- Edit that file or the overrides, then run the script. Do not edit here.",
        "-- Packaged in-game screenshots, by CVar and level. A setting without an",
        "-- entry falls back to a labeled schematic. See docs/GRAPHICS_ASSETS.md.",
        "local _, ns = ...",
        "",
    ]
    settings = manifest.get("settings", {})
    if not settings:
        lines.append("ns.Manifest = {}")
        return "\n".join(lines) + "\n"
    lines.append("ns.Manifest = {")
    for cvar in sorted(settings):
        entry = settings[cvar]
        lines.append(f"\t{cvar} = {{")
        lines.append(f"\t\tbuild = {lua_string(entry['build'])},")
        lines.append(f"\t\tnote = {lua_string(entry['note'])},")
        for level in LEVELS:
            lines.append(f"\t\t{level} = {lua_string(MEDIA + cvar + '_' + level)},")
        lines.append("\t\tcoords = { " + ", ".join(lua_number(v) for v in entry["coords"]) + " },")
        if entry.get("focus"):
            lines.append("\t\tfocus = { " + ", ".join(lua_number(v) for v in entry["focus"]) + " },")
        values = ", ".join(f"{level} = {lua_number(entry['values'][level])}" for level in LEVELS)
        lines.append(f"\t\tvalues = {{ {values} }},")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def read_json(path, default):
    path = Path(path)
    return json.loads(path.read_text()) if path.exists() else default


def write_json(path, data):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


# ----- Review page ------------------------------------------------------

def data_uri(img, width):
    img = img.copy()
    img.thumbnail((width, width * 4))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=82)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def outlined(img, crop):
    img = img.convert("RGB").copy()
    x, y, w, h = crop
    ImageDraw.Draw(img).rectangle((x, y, x + w - 1, y + h - 1), outline=(255, 90, 80),
                                  width=max(2, img.size[0] // 300))
    return img


def heat(sig):
    top = float(sig.max()) or 1.0
    v = np.clip(sig / top, 0, 1)
    rgb = np.stack([v * 255, v * 170, 40 + v * 30], axis=2).astype(np.uint8)
    return Image.fromarray(rgb)


def panel_view(img, crop, focus):
    view = img.crop(tuple(crop[:2]) + (crop[0] + crop[2], crop[1] + crop[3])).resize(PANEL, Image.LANCZOS)
    if focus:
        x, y, w, h = focus
        ImageDraw.Draw(view).rectangle(
            (x * PANEL[0], y * PANEL[1], (x + w) * PANEL[0], (y + h) * PANEL[1]),
            outline=(255, 90, 77), width=2)
    return view


def review_html(run_number, run, sections, problems):
    css = """
    body{margin:0;background:#141a33;color:#e8ecff;font:14px/1.5 -apple-system,Segoe UI,sans-serif}
    main{max-width:1500px;margin:auto;padding:24px}
    h1{font-size:22px;margin:0 0 4px} h2{font-size:18px;margin:0}
    .muted{color:#a9b2e0} .bad{color:#ff7a6b} .ok{color:#6fe3a2} .warn{color:#ffd166}
    section{background:#1d2547;border:1px solid #2f3a6e;border-radius:10px;padding:16px;margin:18px 0}
    .row{display:flex;gap:10px;flex-wrap:wrap;margin-top:10px}
    figure{margin:0} figcaption{font-size:12px;color:#a9b2e0}
    img{display:block;border-radius:4px;max-width:100%}
    code{background:#0f1430;padding:1px 5px;border-radius:4px}
    ul{margin:6px 0}
    """
    parts = [f"<!doctype html><meta charset=utf-8><title>GSM capture review</title><style>{css}</style><main>",
             f"<h1>Capture review, run {run_number}</h1>",
             f"<p class=muted>Build {run.get('build')}, {run.get('zone')}, started {run.get('started')}. "
             "Red boxes on the full frames are the crop. The orange map is the change GSM found. "
             "Check each crop, then commit or fix it in "
             f"<code>{OVERRIDES_JSON}</code>.</p>"]
    if problems:
        parts.append("<section><h2 class=warn>Problems</h2><ul>")
        parts += [f"<li>{p}</li>" for p in problems]
        parts.append("</ul></section>")
    for s in sections:
        flag = ("<span class=bad>No visible change found. Check the camera and the settle time.</span>"
                if s["no_change"] else f"<span class=ok>Crop holds {s['share'] * 100:.0f}% of the change.</span>")
        parts.append(f"<section><h2>{s['label']} <span class=muted>{s['cvar']}</span></h2><p>{flag} "
                     f"Values: {s['values_text']}. Crop {s['crop']} of a {s['size'][0]}x{s['size'][1]} world area."
                     f"{' Override applied.' if s['override'] else ''}</p><div class=row>")
        for name, img in s["frames"]:
            parts.append(f"<figure><img src='{data_uri(img, 360)}' width=360><figcaption>{name}</figcaption></figure>")
        parts.append(f"<figure><img src='{data_uri(s['heat'], 360)}' width=360><figcaption>Change map</figcaption></figure>")
        parts.append("</div><div class=row>")
        for name, img in s["panels"]:
            parts.append(f"<figure><img src='{data_uri(img, PANEL[0])}' width={PANEL[0]} height={PANEL[1]}>"
                         f"<figcaption>{name}, as the panel shows it</figcaption></figure>")
        parts.append("</div></section>")
    parts.append("</main>")
    return "\n".join(parts)


# ----- Commands ---------------------------------------------------------

def cmd_dates(args):
    _, run = pick_run(load_log(args.log), args.run)
    for date in sorted({s["stamp"][:6] for s in listify(run.get("shots"))}):
        print(date)


def cmd_manifest(args):
    repo = Path(args.repo)
    manifest = read_json(repo / MANIFEST_JSON, {"settings": {}})
    (repo / MANIFEST_LUA).write_text(manifest_lua(manifest))
    print(f"Wrote {MANIFEST_LUA} ({len(manifest.get('settings', {}))} settings).")


def group_shots(run):
    by_cvar = {}
    for shot in listify(run.get("shots")):
        by_cvar.setdefault(shot["cvar"], {})[shot["shot"]] = shot
    return by_cvar


def cmd_import(args):
    repo = Path(args.repo)
    number, run = pick_run(load_log(args.log), args.run)
    shots = listify(run.get("shots"))
    paths = match_files(shots, args.screens)
    for shot, path in zip(shots, paths):
        shot["path"] = path
    band = run.get("band") or DEFAULT_BAND
    problems = []
    if not run.get("band"):
        problems.append(f"The run did not record the caption band height. Assumed {DEFAULT_BAND}.")
    for skipped in listify(run.get("skipped")):
        problems.append(f"{skipped['cvar']} {skipped['shot']} was skipped in game: {skipped['message']}.")
    if run.get("result") != "done":
        problems.append(f"The run ended early: {run.get('result')}.")

    only = set(filter(None, (args.only or "").split(",")))
    overrides = read_json(repo / OVERRIDES_JSON, {})
    manifest = read_json(repo / MANIFEST_JSON, {"settings": {}})
    shots_dir = repo / SHOTS_DIR
    shots_dir.mkdir(parents=True, exist_ok=True)
    sections, imported = [], []
    labels = run.get("labels") or {}

    for cvar, group in group_shots(run).items():
        if only and cvar not in only:
            continue
        override = overrides.get(cvar, {})
        if override.get("skip"):
            problems.append(f"{cvar} skipped by the overrides file: {override.get('reason', 'no reason given')}.")
            continue
        missing = [lvl for lvl in LEVELS if lvl not in group or group[lvl].get("path") is None]
        if missing:
            problems.append(f"{cvar}: no screenshot found for {', '.join(missing)}. Not imported.")
            continue
        images = [load_rgb(group[lvl]["path"]) for lvl in LEVELS]
        control_shot = group.get("control")
        control = None
        if control_shot and control_shot.get("path"):
            control = load_rgb(control_shot["path"])
        else:
            problems.append(f"{cvar}: no control shot, so moving water or weather may pull the crop.")
        if len({img.size for img in images + ([control] if control else [])}) != 1:
            problems.append(f"{cvar}: screenshots differ in size. Not imported.")
            continue
        result = analyze(images, control, band)
        if override:
            apply_override(result, override)
        values = {lvl: group[lvl].get("actual", group[lvl].get("requested")) for lvl in LEVELS}
        if len(set(values.values())) < 3:
            problems.append(f"{cvar}: two levels have the same value ({values}). The game may have clamped one.")
        for lvl, img in zip(LEVELS, result["worlds"]):
            render(img, result["crop"]).save(shots_dir / f"{cvar}_{lvl}.tga")
        zone = run.get("zone") or "Unknown zone"
        manifest.setdefault("settings", {})[cvar] = {
            "build": run.get("build") or "unknown",
            "zone": zone,
            "captured": run.get("started"),
            "note": override.get("note") or f"{zone}. Fixed camera, only this setting changed.",
            "values": values,
            "coords": [round(v, 6) for v in COORDS],
            "focus": result["focus"],
            "crop": result["crop"],
            "source": list(result["worlds"][0].size),
            "share": result["share"],
            "files": {lvl: group[lvl]["path"].name for lvl in LEVELS},
        }
        imported.append(cvar)
        frames = [(lvl.title(), outlined(img, result["crop"])) for lvl, img in zip(LEVELS, result["worlds"])]
        if result["control"] is not None:
            frames.append(("Low again (control)", outlined(result["control"], result["crop"])))
        sections.append({
            "cvar": cvar, "label": labels.get(cvar, cvar), "no_change": result["no_change"],
            "share": result["share"], "crop": result["crop"], "size": result["worlds"][0].size,
            "override": bool(override), "frames": frames, "heat": heat(result["signal"]),
            "values_text": " / ".join(str(values[lvl]) for lvl in LEVELS),
            "panels": [(lvl.title(), panel_view(img, result["crop"], result["focus"]))
                       for lvl, img in zip(LEVELS, result["worlds"])],
        })
        status = "NO CHANGE FOUND" if result["no_change"] else f"{result['share'] * 100:.0f}% of change in crop"
        print(f"{cvar}: crop {result['crop']}, {status}")

    write_json(repo / MANIFEST_JSON, manifest)
    (repo / MANIFEST_LUA).write_text(manifest_lua(manifest))
    review = repo / REVIEW
    review.parent.mkdir(parents=True, exist_ok=True)
    review.write_text(review_html(number, run, sections, problems))
    for p in problems:
        print("note: " + p)
    print(f"Imported {len(imported)} settings from run {number}. Review: {REVIEW}")
    return 0 if imported else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("dates")
    p.add_argument("--log", required=True)
    p.add_argument("--run", type=int)
    p = sub.add_parser("import")
    p.add_argument("--log", required=True)
    p.add_argument("--screens", required=True)
    p.add_argument("--repo", required=True)
    p.add_argument("--run", type=int)
    p.add_argument("--only")
    p = sub.add_parser("manifest")
    p.add_argument("--repo", required=True)
    args = parser.parse_args(argv)
    return {"dates": cmd_dates, "import": cmd_import, "manifest": cmd_manifest}[args.command](args) or 0


if __name__ == "__main__":
    sys.exit(main())
