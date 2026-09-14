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
print(f"Web build: {version}")
