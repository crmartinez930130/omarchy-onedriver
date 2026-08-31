import os
from .graph import GraphClient
from .ipc import serve
from .oauth import OAuthClient
from .tokens import TokenStore
from .transfers import TransferManager


class Helper:
    def __init__(self):
        self.store = TokenStore()
        self.tokens = self.store.load()
        self.events = []
        self.transfers = None

    def dispatch(self, method, params):
        if method == "auth.status":
            return {"signedIn": bool(self.tokens)}
        if method == "auth.logout":
            self.store.clear()
            self.tokens = None
            return {"signedIn": False}
        if method == "auth.refresh":
            return self.refresh()
        if method == "drive.list":
            if not self.tokens:
                raise RuntimeError("Not authenticated")
            return {"items": GraphClient(self.tokens["access_token"]).list_children(params.get("itemId"))}
        if method == "transfer.list":
            return self._manager().list()
        if method == "transfer.cancel":
            return self._manager().cancel(params["transferId"])
        if method == "transfer.download":
            return self._manager().start_download(params["itemId"], params["destination"], params["name"])
        if method == "transfer.upload":
            return self._manager().start_upload(params["parentId"], params["source"], params["name"])
        if method == "auth.login":
            return self.login()
        raise ValueError("Unknown method")

    def _manager(self):
        if not self.tokens:
            raise RuntimeError("Not authenticated")
        if self.transfers is None:
            self.transfers = TransferManager(GraphClient(self.tokens["access_token"]), self._event, __import__("urllib.request", fromlist=["urlopen"]).urlopen)
        return self.transfers

    def _event(self, event, payload):
        self.events.append({"event": event, "payload": payload})

    def login(self):
        client_id = os.environ.get("ONEDRIVE_CLIENT_ID")
        if not client_id:
            raise RuntimeError("ONEDRIVE_CLIENT_ID is not configured")
        self.tokens = OAuthClient(client_id).authenticate()
        self.store.save(self.tokens)
        return {"signedIn": True}

    def refresh(self):
        if not self.tokens or not self.tokens.get("refresh_token"):
            raise RuntimeError("No refresh token available")
        refreshed = OAuthClient(os.environ["ONEDRIVE_CLIENT_ID"]).refresh(self.tokens["refresh_token"])
        refreshed.setdefault("refresh_token", self.tokens["refresh_token"])
        self.tokens = refreshed
        self.store.save(self.tokens)
        return {"signedIn": True}


if __name__ == "__main__":
    serve(Helper().dispatch)