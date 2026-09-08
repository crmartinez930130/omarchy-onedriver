import os
import urllib.request
from .graph import GraphClient, GraphError
from .ipc import serve
from .oauth import OAuthClient
from .sync import FolderSync, SyncStateStore
from .tokens import TokenStore
from .transfers import TransferManager


class Helper:
    def __init__(self):
        self.store = TokenStore()
        self.tokens = self.store.load()
        self.events = []
        self.transfers = None
        self.sync = FolderSync(get_manager=self._manager, get_graph=self._graph, state_store=SyncStateStore())
        self.sync.start()

    def dispatch(self, method, params):
        try:
            return self._dispatch(method, params)
        except GraphError as error:
            if error.status != 401:
                raise
            if self._try_refresh():
                return self._dispatch(method, params)
            raise RuntimeError("Session expired — please sign in again") from error

    def _try_refresh(self):
        if self.tokens and self.tokens.get("refresh_token"):
            try:
                self.refresh()
                return True
            except Exception:
                pass
        self.store.clear()
        self.tokens = None
        self.transfers = None
        return False

    def _dispatch(self, method, params):
        if method == "auth.status":
            return {"signedIn": bool(self.tokens)}
        if method == "auth.logout":
            self.store.clear()
            self.tokens = None
            return {"signedIn": False}
        if method == "auth.refresh":
            return self.refresh()
        if method == "auth.me":
            return self._graph().me()
        if method == "drive.quota":
            return self._graph().quota()
        if method == "drive.list":
            return {"items": self._graph().list_children(params.get("itemId"))}
        if method == "drive.mkdir":
            return self._graph().create_folder(params["parentId"], params["name"])
        if method == "drive.rename":
            return self._graph().rename(params["itemId"], params["name"])
        if method == "drive.delete":
            return self._graph().delete(params["itemId"])
        if method == "transfer.list":
            return self._manager().list()
        if method == "transfer.cancel":
            return self._manager().cancel(params["transferId"])
        if method == "transfer.dismiss":
            return self._manager().dismiss(params["transferId"])
        if method == "transfer.download":
            return self._manager().start_download(params["itemId"], params["destination"], params["name"])
        if method == "transfer.upload":
            return self._manager().start_upload(params["parentId"], params["source"], params["name"])
        if method == "sync.configure":
            self.sync.configure(params.get("folders", []))
            return {"configured": True}
        if method == "auth.login":
            return self.login()
        raise ValueError("Unknown method")

    def _graph(self):
        if not self.tokens:
            raise RuntimeError("Not authenticated")
        return GraphClient(self.tokens["access_token"])

    def _manager(self):
        if not self.tokens:
            raise RuntimeError("Not authenticated")
        if self.transfers is None:
            self.transfers = TransferManager(GraphClient(self.tokens["access_token"]), self._event, urllib.request.urlopen, on_unauthorized=self._try_refresh)
        return self.transfers

    def _event(self, event, payload):
        self.events.append({"event": event, "payload": payload})

    def login(self):
        client_id = os.environ.get("ONEDRIVE_CLIENT_ID")
        if not client_id:
            raise RuntimeError("ONEDRIVE_CLIENT_ID is not configured")
        self.tokens = OAuthClient(client_id).authenticate()
        self.store.save(self.tokens)
        self.transfers = None
        return {"signedIn": True}

    def refresh(self):
        if not self.tokens or not self.tokens.get("refresh_token"):
            raise RuntimeError("No refresh token available")
        refreshed = OAuthClient(os.environ["ONEDRIVE_CLIENT_ID"]).refresh(self.tokens["refresh_token"])
        refreshed.setdefault("refresh_token", self.tokens["refresh_token"])
        self.tokens = refreshed
        self.store.save(self.tokens)
        if self.transfers is not None:
            self.transfers.graph.access_token = self.tokens["access_token"]
        return {"signedIn": True}


if __name__ == "__main__":
    serve(Helper().dispatch)