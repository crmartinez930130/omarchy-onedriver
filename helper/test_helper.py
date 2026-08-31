import io
import json
import tempfile
import unittest
from pathlib import Path

from ipc import serve
from tokens import TokenStore


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


if __name__ == "__main__":
    unittest.main()