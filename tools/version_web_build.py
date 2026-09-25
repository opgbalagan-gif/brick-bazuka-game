"""Version the exported pack URL so browsers fetch the current game after rebuilds."""

import hashlib
import json
import re
from pathlib import Path


root = Path(__file__).resolve().parents[1]
pack = root / "docs" / "index.pck"
page = root / "docs" / "index.html"
version = hashlib.sha256(pack.read_bytes()).hexdigest()[:12]
html = page.read_text(encoding="utf-8")
match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
if not match:
    raise SystemExit("Godot export configuration was not found")
config = json.loads(match.group(1))
config["mainPack"] = f"index.pck?v={version}"
config["fileSizes"] = {key: value for key, value in config["fileSizes"].items() if not key.startswith("index.pck?")}
config["fileSizes"][config["mainPack"]] = pack.stat().st_size
page.write_text(html[:match.start(1)] + json.dumps(config, separators=(",", ":")) + html[match.end(1):], encoding="utf-8")
tilt_source = root / "web" / "tilt-control.js"
tilt_script = tilt_source.read_bytes()
(root / "docs" / "tilt-control.js").write_bytes(tilt_script)
tilt_version = hashlib.sha256(tilt_script).hexdigest()[:12]
html = page.read_text(encoding="utf-8")
html = re.sub(r'\s*<script src="tilt-control\.js(?:\?v=[a-f0-9]+)?"></script>', '', html)
html = html.replace('<script src="index.js"></script>', f'<script src="tilt-control.js?v={tilt_version}"></script>\n\t\t<script src="index.js"></script>')
page.write_text(html, encoding="utf-8")
name_script = (root / "web" / "name-input.js").read_bytes()
(root / "docs" / "name-input.js").write_bytes(name_script)
name_version = hashlib.sha256(name_script).hexdigest()[:12]
html = re.sub(r'\s*<script src="name-input\.js(?:\?v=[a-f0-9]+)?"></script>', '', html)
html = html.replace('<script src="index.js"></script>', f'<script src="name-input.js?v={name_version}"></script>\n\t\t<script src="index.js"></script>')
page.write_text(html, encoding="utf-8")
print(f"Web build: {version}")

api_source = (root / "scripts" / "leaderboard.gd").read_text(encoding="utf-8")
api_url = re.search(r'const API_URL := "([^"]+)"', api_source).group(1)
board_script = (root / "web" / "leaderboard.js").read_bytes()
(root / "docs" / "leaderboard.js").write_bytes(board_script)
board_version = hashlib.sha256(board_script).hexdigest()[:12]
board_html = (root / "web" / "leaderboard.html").read_text(encoding="utf-8").replace("__API_URL__", api_url)
board_html = board_html.replace('src="leaderboard.js"', f'src="leaderboard.js?v={board_version}"')
board_html = board_html.replace('href="./"', f'href="./?v={version}"')
(root / "docs" / "leaderboard.html").write_text(board_html, encoding="utf-8")
(root / "docs" / "leaderboard-snapshot.json").write_bytes((root / "assets" / "data" / "leaderboard_snapshot.json").read_bytes())
