import io
import json
import os
import sys
import tempfile
import threading
import time
import unittest
import urllib.request
from pathlib import Path
from unittest.mock import patch

from ipc import serve
from tokens import TokenStore

# main.py uses a relative import (`from .graph import ...`), so it can only be
# imported as part of the `helper` package, not as the bare `main` the rest of
# this file uses for ipc/tokens. Put the project root on the path for that.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from helper.graph import GraphClient, GraphError, _DropAuthOnRedirect
from helper.main import Helper
from helper.sync import FolderSync, SyncStateStore
from helper.transfers import TransferManager


class HelperTests(unittest.TestCase):
    def test_ipc_response_contract(self):
        output = io.StringIO()
        serve(lambda method, params: {"method": method}, io.StringIO('{"id":"1","method":"auth.status","params":{}}\n'), output)
        self.assertEqual(json.loads(output.getvalue()), {"id": "1", "ok": True, "result": {"method": "auth.status"}, "error": None})

    def test_token_store_uses_restricted_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tokens.json"
            store = TokenStore(path)
            store.save({"access_token": "secret"})
            self.assertEqual(store.load()["access_token"], "secret")
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_redirect_handler_drops_the_bearer_token(self):
        # Graph's /content redirects to a different host for the actual file
        # bytes; urllib's default redirect handling would otherwise carry our
        # Authorization header over to that host, which rejects it with a 401.
        original = urllib.request.Request(
            "https://graph.microsoft.com/v1.0/me/drive/items/x/content",
            headers={"Authorization": "Bearer secret"},
        )
        redirected = _DropAuthOnRedirect().redirect_request(
            original, None, 302, "Found", {}, "https://blob.example.com/file?sig=abc"
        )
        self.assertEqual(redirected.full_url, "https://blob.example.com/file?sig=abc")
        self.assertNotIn("Authorization", redirected.headers)

    def test_root_level_operations_use_the_root_path_not_an_empty_item_id(self):
        # parent_id/item_id is "" at the drive root (there's no id for root
        # itself). /me/drive/items/:/name:/... and /me/drive/items//children
        # are malformed and Graph 400s on them — "root" is the path it wants.
        opener = _RecordingOpener(json.dumps({"value": [], "uploadUrl": "https://upload.example.com/session"}).encode())
        client = GraphClient("token", opener=opener)

        client.list_children("")
        client.create_folder("", "New folder")
        client.create_upload_session("", "file.txt")

        for url in opener.urls:
            self.assertNotIn("items/:", url)
            self.assertNotIn("items//", url)
        self.assertTrue(opener.urls[0].endswith("/me/drive/root/children"))
        self.assertTrue(opener.urls[1].endswith("/me/drive/root/children"))
        self.assertTrue(opener.urls[2].endswith("/me/drive/root:/file.txt:/createUploadSession"))

    def test_quota_reads_used_and_total_from_the_drive_response(self):
        opener = _RecordingOpener(json.dumps({"quota": {"used": 123, "total": 456, "remaining": 333}}).encode())
        client = GraphClient("token", opener=opener)
        self.assertEqual(client.quota(), {"used": 123, "total": 456})
        self.assertTrue(opener.urls[0].endswith("/me/drive"))

    def test_quota_defaults_to_zero_when_the_field_is_missing(self):
        opener = _RecordingOpener(json.dumps({}).encode())
        client = GraphClient("token", opener=opener)
        self.assertEqual(client.quota(), {"used": 0, "total": 0})


class _RecordingOpener:
    def __init__(self, body):
        self.body = body
        self.urls = []

    def __call__(self, request):
        self.urls.append(request.full_url)
        return io.BytesIO(self.body)


class FakeGraphClient:
    def __init__(self, access_token):
        self.access_token = access_token

    def list_children(self, item_id=None):
        if self.access_token == "expired-token":
            raise GraphError(401, "InvalidAuthenticationToken")
        return [{"id": "1", "name": "ok", "folder": None, "size": 0, "lastModifiedDateTime": None, "webUrl": None}]


class FakeOAuthClient:
    def __init__(self, client_id):
        self.client_id = client_id

    def refresh(self, refresh_token):
        return {"access_token": "fresh-token", "refresh_token": refresh_token}


class HelperRefreshTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        env_patch = patch.dict(os.environ, {"XDG_STATE_HOME": self.tempdir.name, "ONEDRIVE_CLIENT_ID": "test-client-id"})
        env_patch.start()
        self.addCleanup(env_patch.stop)
        self.helper = Helper()
        self.helper.tokens = {"access_token": "expired-token", "refresh_token": "valid-refresh"}

    @patch("helper.main.GraphClient", FakeGraphClient)
    @patch("helper.main.OAuthClient", FakeOAuthClient)
    def test_expired_token_is_refreshed_and_the_call_retried(self):
        result = self.helper.dispatch("drive.list", {})
        self.assertEqual(result["items"][0]["name"], "ok")
        self.assertEqual(self.helper.tokens["access_token"], "fresh-token")

    @patch("helper.main.GraphClient", FakeGraphClient)
    @patch("helper.main.OAuthClient")
    def test_failed_refresh_clears_the_session(self, mock_oauth_client):
        mock_oauth_client.return_value.refresh.side_effect = RuntimeError("invalid_grant")
        with self.assertRaises(RuntimeError):
            self.helper.dispatch("drive.list", {})
        self.assertIsNone(self.helper.tokens)

    @patch("helper.main.GraphClient", FakeGraphClient)
    def test_no_refresh_token_clears_the_session(self):
        self.helper.tokens = {"access_token": "expired-token"}
        with self.assertRaises(RuntimeError):
            self.helper.dispatch("drive.list", {})
        self.assertIsNone(self.helper.tokens)


class FakeDownloadResponse:
    def __init__(self, data):
        self.data = data
        self.headers = {"Content-Length": str(len(data))}
        self._sent = False

    def read(self, size=None):
        if self._sent:
            return b""
        self._sent = True
        return self.data


class FakeTransferGraph:
    def __init__(self):
        self.access_token = "expired-token"
        self.download_calls = 0

    def download_request(self, item_id):
        self.download_calls += 1
        if self.access_token == "expired-token":
            raise GraphError(401, "InvalidAuthenticationToken")
        return FakeDownloadResponse(b"hello")


def _make_job():
    return {"id": "t1", "direction": "download", "name": "downloaded.txt",
            "bytesCompleted": 0, "bytesTotal": 0, "state": "running",
            "error": None, "finishedAt": None, "cancel": threading.Event()}


class TransferManagerRefreshTests(unittest.TestCase):
    def test_download_refreshes_expired_token_and_retries(self):
        graph = FakeTransferGraph()

        def on_unauthorized():
            graph.access_token = "fresh-token"
            return True

        manager = TransferManager(graph, emit=lambda *args: None, opener=None, on_unauthorized=on_unauthorized)
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "downloaded.txt"
            manager._download(_make_job(), "item-1", destination)
            self.assertEqual(destination.read_bytes(), b"hello")
        self.assertEqual(graph.download_calls, 2)

    def test_download_without_a_working_refresh_raises(self):
        graph = FakeTransferGraph()
        manager = TransferManager(graph, emit=lambda *args: None, opener=None, on_unauthorized=lambda: False)
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "downloaded.txt"
            with self.assertRaises(GraphError):
                manager._download(_make_job(), "item-1", destination)
        self.assertEqual(graph.download_calls, 1)


class TransferManagerLifecycleTests(unittest.TestCase):
    def _manager(self):
        return TransferManager(graph=None, emit=lambda *args: None, opener=None)

    def test_dismiss_removes_a_finished_transfer(self):
        manager = self._manager()
        job = _make_job()
        job["state"] = "completed"
        job["finishedAt"] = time.monotonic()
        manager.jobs["t1"] = job
        manager.dismiss("t1")
        self.assertEqual(manager.list(), [])

    def test_dismiss_refuses_a_transfer_still_in_progress(self):
        manager = self._manager()
        manager.jobs["t1"] = _make_job()
        with self.assertRaises(ValueError):
            manager.dismiss("t1")
        self.assertEqual(len(manager.list()), 1)

    def test_dismiss_refuses_an_unknown_transfer(self):
        manager = self._manager()
        with self.assertRaises(ValueError):
            manager.dismiss("missing")

    def test_list_purges_transfers_finished_over_an_hour_ago(self):
        manager = self._manager()
        job = _make_job()
        job["state"] = "completed"
        job["finishedAt"] = time.monotonic() - 3700
        manager.jobs["t1"] = job
        self.assertEqual(manager.list(), [])

    def test_list_keeps_recently_finished_transfers(self):
        manager = self._manager()
        job = _make_job()
        job["state"] = "completed"
        job["finishedAt"] = time.monotonic() - 10
        manager.jobs["t1"] = job
        result = manager.list()
        self.assertEqual(len(result), 1)
        self.assertNotIn("finishedAt", result[0])


class SyncStateStoreTests(unittest.TestCase):
    def test_round_trip_persists_across_instances(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sync_state.json"
            store = SyncStateStore(path)
            store.set("/local", "a.txt", {"mtime": 1.0, "size": 2})
            reloaded = SyncStateStore(path)
            self.assertEqual(reloaded.get("/local", "a.txt"), {"mtime": 1.0, "size": 2})

    def test_missing_entry_returns_none(self):
        with tempfile.TemporaryDirectory() as directory:
            store = SyncStateStore(Path(directory) / "sync_state.json")
            self.assertIsNone(store.get("/local", "a.txt"))


class FakeSyncGraph:
    def __init__(self):
        self.calls = []
        self._next_id = 1
        self._existing = {}

    def find_or_create_folder(self, parent_id, name):
        self.calls.append((parent_id, name))
        key = (parent_id, name.lower())
        if key not in self._existing:
            self._existing[key] = f"folder-{self._next_id}"
            self._next_id += 1
        return self._existing[key]


class FakeSyncManager:
    def __init__(self, final_state="completed"):
        self.uploads = []
        self.final_state = final_state

    def start_upload(self, parent_id, source, name, on_complete=None):
        self.uploads.append((parent_id, source, name))
        if on_complete:
            on_complete({"id": "t", "state": self.final_state})


class FolderSyncTests(unittest.TestCase):
    def _syncer(self, manager, graph, state_dir):
        store = SyncStateStore(Path(state_dir) / "sync_state.json")
        return FolderSync(get_manager=lambda: manager, get_graph=lambda: graph, state_store=store)

    def test_scan_uploads_new_files_and_mirrors_subfolders(self):
        with tempfile.TemporaryDirectory() as local_dir, tempfile.TemporaryDirectory() as state_dir:
            root = Path(local_dir) / "Sync"
            (root / "sub").mkdir(parents=True)
            (root / "top.txt").write_text("hello")
            (root / "sub" / "nested.txt").write_text("world")

            manager = FakeSyncManager()
            graph = FakeSyncGraph()
            syncer = self._syncer(manager, graph, state_dir)
            syncer.configure([{"path": str(root), "enabled": True}])
            syncer._scan_once()

            names = sorted(name for (_parent, _source, name) in manager.uploads)
            self.assertEqual(names, ["nested.txt", "top.txt"])
            top_parent = next(p for p, _s, n in manager.uploads if n == "top.txt")
            nested_parent = next(p for p, _s, n in manager.uploads if n == "nested.txt")
            self.assertNotEqual(top_parent, nested_parent)
            self.assertIn((None, "Sync"), graph.calls)
            self.assertIn((top_parent, "sub"), graph.calls)

    def test_scan_skips_files_already_synced(self):
        with tempfile.TemporaryDirectory() as local_dir, tempfile.TemporaryDirectory() as state_dir:
            root = Path(local_dir) / "Sync"
            root.mkdir()
            (root / "top.txt").write_text("hello")

            manager = FakeSyncManager()
            syncer = self._syncer(manager, FakeSyncGraph(), state_dir)
            syncer.configure([{"path": str(root), "enabled": True}])
            syncer._scan_once()
            self.assertEqual(len(manager.uploads), 1)

            manager.uploads.clear()
            syncer._scan_once()
            self.assertEqual(manager.uploads, [])

    def test_failed_upload_is_retried_next_scan(self):
        with tempfile.TemporaryDirectory() as local_dir, tempfile.TemporaryDirectory() as state_dir:
            root = Path(local_dir) / "Sync"
            root.mkdir()
            (root / "top.txt").write_text("hello")

            manager = FakeSyncManager(final_state="failed")
            syncer = self._syncer(manager, FakeSyncGraph(), state_dir)
            syncer.configure([{"path": str(root), "enabled": True}])
            syncer._scan_once()
            manager.uploads.clear()
            syncer._scan_once()
            self.assertEqual(len(manager.uploads), 1)

    def test_disabled_or_empty_list_does_nothing(self):
        with tempfile.TemporaryDirectory() as local_dir, tempfile.TemporaryDirectory() as state_dir:
            root = Path(local_dir) / "Sync"
            root.mkdir()
            (root / "top.txt").write_text("hello")

            manager = FakeSyncManager()
            syncer = self._syncer(manager, FakeSyncGraph(), state_dir)
            syncer.configure([{"path": str(root), "enabled": False}])
            syncer._scan_once()
            self.assertEqual(manager.uploads, [])

            syncer.configure([])
            syncer._scan_once()
            self.assertEqual(manager.uploads, [])

    def test_scans_multiple_folders_independently(self):
        with tempfile.TemporaryDirectory() as local_dir, tempfile.TemporaryDirectory() as state_dir:
            first = Path(local_dir) / "First"
            second = Path(local_dir) / "Second"
            first.mkdir()
            second.mkdir()
            (first / "a.txt").write_text("a")
            (second / "b.txt").write_text("b")

            manager = FakeSyncManager()
            graph = FakeSyncGraph()
            syncer = self._syncer(manager, graph, state_dir)
            syncer.configure([
                {"path": str(first), "enabled": True},
                {"path": str(second), "enabled": True},
            ])
            syncer._scan_once()

            names = sorted(name for (_parent, _source, name) in manager.uploads)
            self.assertEqual(names, ["a.txt", "b.txt"])
            first_parent = next(p for p, _s, n in manager.uploads if n == "a.txt")
            second_parent = next(p for p, _s, n in manager.uploads if n == "b.txt")
            self.assertNotEqual(first_parent, second_parent)

    def test_only_enabled_folders_in_a_mixed_list_are_scanned(self):
        with tempfile.TemporaryDirectory() as local_dir, tempfile.TemporaryDirectory() as state_dir:
            on_dir = Path(local_dir) / "On"
            off_dir = Path(local_dir) / "Off"
            on_dir.mkdir()
            off_dir.mkdir()
            (on_dir / "a.txt").write_text("a")
            (off_dir / "b.txt").write_text("b")

            manager = FakeSyncManager()
            syncer = self._syncer(manager, FakeSyncGraph(), state_dir)
            syncer.configure([
                {"path": str(on_dir), "enabled": True},
                {"path": str(off_dir), "enabled": False},
            ])
            syncer._scan_once()

            names = [name for (_parent, _source, name) in manager.uploads]
            self.assertEqual(names, ["a.txt"])

    def test_configure_drops_duplicate_paths(self):
        syncer = self._syncer(FakeSyncManager(), FakeSyncGraph(), tempfile.mkdtemp())
        syncer.configure([
            {"path": "/same", "enabled": False},
            {"path": "/same", "enabled": True},
        ])
        self.assertEqual(syncer.folders, [{"path": "/same", "enabled": False}])


if __name__ == "__main__":
    unittest.main()