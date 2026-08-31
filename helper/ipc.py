import json
import sys


def serve(dispatch, input_stream=sys.stdin, output_stream=sys.stdout, event_sink=None):
    for line in input_stream:
        try:
            request = json.loads(line)
            result = dispatch(request["method"], request.get("params", {}))
            response = {"id": request["id"], "ok": True, "result": result, "error": None}
        except Exception as error:
            response = {"id": request.get("id"), "ok": False, "result": None, "error": {"message": str(error)}}
        output_stream.write(json.dumps(response) + "\n")
        output_stream.flush()