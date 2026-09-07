import sys
import threading
import time
import traceback
import uuid
from pathlib import Path
from urllib.request import Request

from .graph import GraphError

RETENTION_SECONDS = 3600
_TERMINAL_STATES = ("completed", "cancelled", "failed")


class TransferManager:
    def __init__(self, graph, emit, opener, on_unauthorized=None):
        self.graph = graph
        self.emit = emit
        self.opener = opener
        self.on_unauthorized = on_unauthorized
        self.jobs = {}
        self.lock = threading.Lock()

    def start_download(self, item_id, destination, name):
        return self._start("download", name, lambda job: self._download(job, item_id, Path(destination)))

    def start_upload(self, parent_id, source, name, on_complete=None):
        return self._start("upload", name, lambda job: self._upload(job, parent_id, Path(source), name), on_complete)

    def cancel(self, transfer_id):
        job = self.jobs.get(transfer_id)
        if not job:
            raise ValueError("Unknown transfer")
        job["cancel"].set()
        return {"cancelled": True}

    def dismiss(self, transfer_id):
        with self.lock:
            job = self.jobs.get(transfer_id)
            if not job:
                raise ValueError("Unknown transfer")
            if job["state"] not in _TERMINAL_STATES:
                raise ValueError("Transfer still in progress")
            del self.jobs[transfer_id]
        return {"dismissed": True}

    def list(self):
        with self.lock:
            self._purge_expired()
            return [self._public(job) for job in self.jobs.values()]

    def _purge_expired(self):
        now = time.monotonic()
        expired = [transfer_id for transfer_id, job in self.jobs.items()
                   if job["state"] in _TERMINAL_STATES and now - job["finishedAt"] > RETENTION_SECONDS]
        for transfer_id in expired:
            del self.jobs[transfer_id]

    def _start(self, direction, name, work, on_complete=None):
        transfer_id = uuid.uuid4().hex
        job = {"id": transfer_id, "direction": direction, "name": name,
               "bytesCompleted": 0, "bytesTotal": 0, "state": "queued",
               "error": None, "finishedAt": None, "cancel": threading.Event()}
        with self.lock:
            self.jobs[transfer_id] = job
        threading.Thread(target=self._run, args=(job, work, on_complete), daemon=True).start()
        return self._public(job)

    def _run(self, job, work, on_complete=None):
        job["state"] = "running"
        self._publish(job)
        try:
            work(job)
            job["state"] = "cancelled" if job["cancel"].is_set() else "completed"
        except Exception as error:
            job["state"] = "cancelled" if job["cancel"].is_set() else "failed"
            job["error"] = str(error)
            print(f"[transfer {job['id']}] {job['direction']} of {job['name']!r} failed:", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)
        job["finishedAt"] = time.monotonic()
        self._publish(job)
        if on_complete:
            try:
                on_complete(job)
            except Exception:
                traceback.print_exc(file=sys.stderr)

    def _opening_call(self, call):
        try:
            return call()
        except GraphError as error:
            if error.status == 401 and self.on_unauthorized and self.on_unauthorized():
                return call()
            raise

    def _download(self, job, item_id, destination):
        response = self._opening_call(lambda: self.graph.download_request(item_id))
        total = int(response.headers.get("Content-Length", 0))
        job["bytesTotal"] = total
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("wb") as output:
            while True:
                if job["cancel"].is_set():
                    return
                chunk = response.read(1024 * 1024)
                if not chunk:
                    return
                output.write(chunk)
                job["bytesCompleted"] += len(chunk)
                self._publish(job)

    def _upload(self, job, parent_id, source, name):
        size = source.stat().st_size
        job["bytesTotal"] = size
        session = self._opening_call(lambda: self.graph.create_upload_session(parent_id, name))
        offset = 0
        with source.open("rb") as source_file:
            while offset < size:
                if job["cancel"].is_set():
                    return
                chunk = source_file.read(min(10 * 1024 * 1024, size - offset))
                request = Request(session, data=chunk, method="PUT", headers={
                    "Content-Length": str(len(chunk)),
                    "Content-Range": f"bytes {offset}-{offset + len(chunk) - 1}/{size}"})
                with self.opener(request):
                    pass
                offset += len(chunk)
                job["bytesCompleted"] = offset
                self._publish(job)

    def _publish(self, job):
        self.emit("transferProgress", self._public(job))

    @staticmethod
    def _public(job):
        return {key: value for key, value in job.items() if key not in ("cancel", "finishedAt")}