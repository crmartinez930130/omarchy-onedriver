import json
import os
import sys
import threading
import time
import traceback
from pathlib import Path

SCAN_INTERVAL_SECONDS = 30


class SyncStateStore:
    # Remembers which (local folder, relative path) fingerprints have already
    # been uploaded, so a restart doesn't re-upload everything that was
    # already synced.
    def __init__(self, path=None):
        self.path = Path(path) if path else Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "onedrive-omarchy" / "sync_state.json"
        self._data = self._load()
        self._lock = threading.Lock()

    def _load(self):
        try:
            return json.loads(self.path.read_text())
        except (FileNotFoundError, ValueError):
            return {}

    def get(self, local_path, relative):
        return self._data.get(local_path, {}).get(relative)

    def set(self, local_path, relative, fingerprint):
        with self._lock:
            self._data.setdefault(local_path, {})[relative] = fingerprint
            self._save()

    def _save(self):
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(self._data))
        temporary.replace(self.path)


class FolderSync:
    # Watches one local folder and uploads anything new or changed into a
    # same-named mirror folder at the OneDrive root, preserving the local
    # subfolder structure. One-way (local -> cloud) only: local deletions
    # never remove the cloud copy, and nothing is ever downloaded back.
    def __init__(self, get_manager, get_graph, state_store, scan_interval=SCAN_INTERVAL_SECONDS):
        self.get_manager = get_manager
        self.get_graph = get_graph
        self.state_store = state_store
        self.scan_interval = scan_interval
        self.local_path = ""
        self.enabled = False
        self._folder_cache = {}
        self._config_lock = threading.Lock()
        self._thread = None

    def configure(self, local_path, enabled):
        local_path = local_path or ""
        with self._config_lock:
            if local_path != self.local_path:
                self._folder_cache = {}
            self.local_path = local_path
            self.enabled = bool(enabled) and local_path != ""

    def start(self):
        # Runs once for the life of the helper process — separate from
        # configure() so the loop is idle (not scanning) until settings
        # arrive, and so tests can call _scan_once() deterministically
        # without a second scan racing it in the background.
        if self._thread is None:
            self._thread = threading.Thread(target=self._loop, daemon=True)
            self._thread.start()

    def _loop(self):
        while True:
            try:
                self._scan_once()
            except Exception:
                traceback.print_exc(file=sys.stderr)
            time.sleep(self.scan_interval)

    def _scan_once(self):
        with self._config_lock:
            local_path, enabled = self.local_path, self.enabled
        if not enabled:
            return
        root = Path(local_path)
        if not root.is_dir():
            return
        try:
            manager = self.get_manager()
            graph = self.get_graph()
        except Exception:
            return  # not signed in yet — retry on the next tick

        mirror_name = root.name or "onedrive-sync"
        for path in sorted(p for p in root.rglob("*") if p.is_file()):
            relative = path.relative_to(root)
            stat = path.stat()
            fingerprint = {"mtime": stat.st_mtime, "size": stat.st_size}
            if self.state_store.get(local_path, str(relative)) == fingerprint:
                continue
            segments = (mirror_name,) + relative.parent.parts
            parent_id = self._remote_folder_id(graph, segments)
            manager.start_upload(parent_id, str(path), path.name,
                                  on_complete=self._make_on_complete(local_path, str(relative), fingerprint))

    def _remote_folder_id(self, graph, segments):
        if segments in self._folder_cache:
            return self._folder_cache[segments]
        parent_id = self._remote_folder_id(graph, segments[:-1]) if len(segments) > 1 else None
        folder_id = graph.find_or_create_folder(parent_id, segments[-1])
        self._folder_cache[segments] = folder_id
        return folder_id

    def _make_on_complete(self, local_path, relative, fingerprint):
        def on_complete(job):
            if job.get("state") == "completed":
                self.state_store.set(local_path, relative, fingerprint)
        return on_complete
