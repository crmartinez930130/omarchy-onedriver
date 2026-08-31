import json
import urllib.error
import urllib.parse
import urllib.request


class GraphError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


class GraphClient:
    base_url = "https://graph.microsoft.com/v1.0"

    def __init__(self, access_token, opener=urllib.request.urlopen):
        self.access_token = access_token
        self.opener = opener

    def _request(self, method, path):
        request = urllib.request.Request(self.base_url + path, method=method, headers={"Authorization": f"Bearer {self.access_token}"})
        try:
            with self.opener(request) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            try:
                payload = json.loads(error.read())
                message = payload.get("error", {}).get("message", "Graph request failed")
            except (ValueError, AttributeError):
                message = "Graph request failed"
            raise GraphError(error.code, message) from error

    def download_request(self, item_id):
        request = urllib.request.Request(self.base_url + f"/me/drive/items/{urllib.parse.quote(item_id)}/content", headers={"Authorization": f"Bearer {self.access_token}"})
        return self.opener(request)

    def create_upload_session(self, parent_id, name):
        result = self._write("POST", f"/me/drive/items/{urllib.parse.quote(parent_id)}:/{urllib.parse.quote(name)}:/createUploadSession", {"item": {"@microsoft.graph.conflictBehavior": "replace"}})
        return result["uploadUrl"]

    @staticmethod
    def _item(item):
        return {"id": item["id"], "name": item["name"], "folder": item.get("folder"), "file": item.get("file"), "size": item.get("size", 0), "lastModifiedDateTime": item.get("lastModifiedDateTime"), "webUrl": item.get("webUrl")}

    def list_children(self, item_id=None):
        path = "/me/drive/root/children" if not item_id else f"/me/drive/items/{urllib.parse.quote(item_id)}/children"
        items = []
        while path:
            page = self._request("GET", path)
            items.extend(self._item(item) for item in page.get("value", []))
            next_link = page.get("@odata.nextLink")
            path = next_link[len(self.base_url):] if next_link and next_link.startswith(self.base_url) else None
        return items

    def create_folder(self, parent_id, name):
        return self._write("POST", f"/me/drive/items/{urllib.parse.quote(parent_id)}/children", {"name": name, "folder": {}})

    def rename(self, item_id, name):
        return self._write("PATCH", f"/me/drive/items/{urllib.parse.quote(item_id)}", {"name": name})

    def delete(self, item_id):
        self._write("DELETE", f"/me/drive/items/{urllib.parse.quote(item_id)}")
        return {"deleted": True}

    def _write(self, method, path, payload=None):
        data = json.dumps(payload).encode() if payload is not None else None
        request = urllib.request.Request(self.base_url + path, data=data, method=method, headers={"Authorization": f"Bearer {self.access_token}", "Content-Type": "application/json"})
        with self.opener(request) as response:
            body = response.read()
            return json.loads(body) if body else {}