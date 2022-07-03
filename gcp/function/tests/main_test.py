import flask
import pytest
from unittest import mock

from src import main


# Create a fake "app" for generating test request contexts.
@pytest.fixture(scope="module")
def app():
    return flask.Flask(__name__)


def test_normal_event(app):
    # set a request context with a fake event
    with app.test_request_context(
        "/",
        method="POST",
        headers={"API_KEY": "test"},
        json={
            "date": "2022-06-08T23:56:23.887Z",
            "hub": "9f44af4c-6347-45b2-ad8a-71261e44b666",
            "deviceId": "8e210490-a654-4342-9c45-3a672c1e24a8",
            "deviceType": "environment",
            "eventId": "9b2d1290-e786-11ec-8593-16df08f7cf1d",
            "device": "Garage Multi",
            "property": "temperature",
            "value": "25.6",
            "unit": "C",
            "isphysical": False,
            "isstatechange": True,
            "source": "DEVICE",
            "location": "Home",
        },
    ):

        # mock the bq client
        with mock.patch("src.main.bigquery") as bq_mock:
            bq_mock.Client = mock.Mock()
            bq_mock.Client.return_value.insert_rows_json = mock.Mock()
            bq_mock.Client.return_value.insert_rows_json.return_value = []

            res = main.event_post(flask.request)

    assert res.status == "201 CREATED"


def test_bigquery_insert_errors(app):
    # set a request context with a fake event
    with app.test_request_context(
        "/",
        method="POST",
        headers={"API_KEY": "test"},
        json={
            "date": "2022-06-08T23:56:23.887Z",
        },
    ):

        # mock the bq client
        with mock.patch("src.main.bigquery") as bq_mock:
            bq_mock.Client = mock.Mock()
            bq_mock.Client.return_value.insert_rows_json = mock.Mock()
            bq_mock.Client.return_value.insert_rows_json.return_value = [
                "bad data when inserting rows"
            ]

            with pytest.raises(Exception) as e:
                res = main.event_post(flask.request)
            assert "bad data when inserting rows" in str(e.value)


def test_method_not_allowed(app):
    with app.test_request_context("/", method="GET", headers={"API_KEY": "test"}):
        with pytest.raises(Exception) as e:
            res = main.event_post(flask.request)
        assert "405 Method Not Allowed" in str(e.value)


def test_json_data_cannot_be_parsed(app):
    with app.test_request_context(
        "/", method="POST", headers={"API_KEY": "test"}, data="ZZZ"
    ):
        with pytest.raises(Exception) as e:
            res = main.event_post(flask.request)
        assert "400 Bad Request" in str(e.value)


def test_api_key_missing(app):
    with app.test_request_context("/", method="POST"):
        with pytest.raises(Exception) as e:
            res = main.event_post(flask.request)
        assert "403 Forbidden" in str(e.value)


def test_api_key_wrong(app):
    with app.test_request_context("/", method="POST", headers={"API_KEY": "xyz"}):
        with pytest.raises(Exception) as e:
            res = main.event_post(flask.request)
        assert "403 Forbidden" in str(e.value)
