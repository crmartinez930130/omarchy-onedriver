import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from ipc import serve
from tokens import TokenStore

# main.py uses a relative import (`from .graph import ...`), so it can only be
# imported as part of the `helper` package, not as the bare `main` the rest of
# this file uses for ipc/tokens. Put the project root on the path for that.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from helper.graph import GraphError
from helper.main import Helper


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


if __name__ == "__main__":
    unittest.main()