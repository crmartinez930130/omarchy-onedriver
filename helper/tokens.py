import json
import os
from pathlib import Path


class TokenStore:
    def __init__(self, path=None):
        self.path = Path(path) if path else Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "onedrive-omarchy" / "tokens.json"

    def load(self):
        try:
            return json.loads(self.path.read_text())
        except FileNotFoundError:
            return None

    def save(self, tokens):
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(tokens))
        temporary.chmod(0o600)
        temporary.replace(self.path)

    def clear(self):
        self.path.unlink(missing_ok=True)