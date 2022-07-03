import os
import functions_framework
import functools
from flask import abort, Response
from google.cloud import bigquery

TABLE_ID = os.getenv("TABLE_ID")  # eg smartthings-logger-351113.smartthings.events
VALID_API_KEY = os.getenv(
    "VALID_API_KEY", "test"
)  # needs to be in request header as api_key

# throw if we can't find the api key and we're running in prod
if VALID_API_KEY == "test" and os.getenv("FUNCTION_TARGET"):
    raise Exception("VALID_API_KEY environment variable not set.")


def api_key_required(func):
    @functools.wraps(func)
    def api_decorator(request):
        k = request.headers.get("api_key")
        if k == VALID_API_KEY:
            return func(request)
        else:
            print(f"Rejecting API key: {k}")
            abort(403)

    return api_decorator


def post_method_required(func):
    @functools.wraps(func)
    def post_decorator(request):
        if request.method == "POST":
            return func(request)
        else:
            abort(405)

    return post_decorator


@functions_framework.http
@api_key_required
@post_method_required
def event_post(request):
    data = request.get_json()
    insert_into_bq(data)

    return Response(response="OK", status=201, content_type="text/plain")


def insert_into_bq(data):
    client = bigquery.Client()

    errors = client.insert_rows_json(TABLE_ID, [data])
    if errors == []:
        return None
    else:
        raise Exception("Error inserting rows: {}".format(errors))
