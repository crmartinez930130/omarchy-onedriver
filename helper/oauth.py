import json
import secrets
import threading
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer


class OAuthClient:
    authorize_url = "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize"
    token_url = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"

    def __init__(self, client_id, redirect_uri="http://127.0.0.1:8765/callback"):
        self.client_id = client_id
        self.redirect_uri = redirect_uri

    def authenticate(self, timeout=120):
        state = secrets.token_urlsafe(24)
        result = {}

        client = self

        class Callback(BaseHTTPRequestHandler):
            def do_GET(self):
                query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
                if query.get("state", [None])[0] != state:
                    result["error"] = "Invalid OAuth state"
                else:
                    result.update({key: values[0] for key, values in query.items()})
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"You can close this window.")
                threading.Thread(target=self.server.shutdown, daemon=True).start()

            def log_message(self, *_args):
                return

        server = HTTPServer((urllib.parse.urlparse(self.redirect_uri).hostname, urllib.parse.urlparse(self.redirect_uri).port), Callback)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        webbrowser.open(self.authorization_url(state))
        thread.join(timeout)
        server.shutdown()
        if "code" not in result:
            raise RuntimeError(result.get("error", "OAuth callback timed out"))
        return self.exchange(result["code"])

    def authorization_url(self, state):
        return self.authorize_url + "?" + urllib.parse.urlencode({"client_id": self.client_id, "response_type": "code", "redirect_uri": self.redirect_uri, "response_mode": "query", "scope": "Files.ReadWrite offline_access", "state": state})

    def exchange(self, code):
        return self._token_request({"client_id": self.client_id, "grant_type": "authorization_code", "code": code, "redirect_uri": self.redirect_uri, "scope": "Files.ReadWrite offline_access"})

    def refresh(self, refresh_token):
        return self._token_request({"client_id": self.client_id, "grant_type": "refresh_token", "refresh_token": refresh_token, "scope": "Files.ReadWrite offline_access"})

    def _token_request(self, values):
        payload = urllib.parse.urlencode(values).encode()
        request = urllib.request.Request(self.token_url, data=payload, method="POST")
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read())