import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from unittest.mock import patch, MagicMock
import sys, os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app
from database import Base, get_db

TEST_DB = "sqlite:///./test_orders.db"
engine = create_engine(TEST_DB, connect_args={"check_same_thread": False})
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
Base.metadata.create_all(bind=engine)

client = TestClient(app)

# ── Mock responses from user-service and product-service ─────────────────────
# In CI there are no running services, so we mock the HTTP calls
MOCK_USER    = {"id": 1, "name": "Priya Sharma", "email": "priya@test.dev"}
MOCK_PRODUCT = {"id": 1, "name": "Headphones", "price": 2999.99, "stock": 50}


def mock_httpx_get(url, **kwargs):
    response = MagicMock()
    response.status_code = 200
    if "/users/" in url:
        response.json.return_value = MOCK_USER
    elif "/products/" in url:
        response.json.return_value = MOCK_PRODUCT
    response.raise_for_status = MagicMock()
    return response


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["service"] == "order-service"


@patch("main.httpx.get", side_effect=mock_httpx_get)
def test_create_order(mock_get):
    r = client.post("/orders", json={"user_id": 1, "product_id": 1, "quantity": 2})
    assert r.status_code == 201
    data = r.json()
    assert data["status"] == "pending"
    assert data["total_price"] == pytest.approx(5999.98)
    assert data["quantity"] == 2


@patch("main.httpx.get", side_effect=mock_httpx_get)
def test_list_orders(mock_get):
    # Create an order first
    client.post("/orders", json={"user_id": 1, "product_id": 1, "quantity": 1})
    r = client.get("/orders")
    assert r.status_code == 200
    assert isinstance(r.json(), list)
    assert len(r.json()) >= 1


@patch("main.httpx.get", side_effect=mock_httpx_get)
def test_get_order_by_id(mock_get):
    create = client.post("/orders", json={"user_id": 1, "product_id": 1, "quantity": 1})
    order_id = create.json()["id"]
    r = client.get(f"/orders/{order_id}")
    assert r.status_code == 200
    assert r.json()["id"] == order_id


def test_get_order_not_found():
    r = client.get("/orders/99999")
    assert r.status_code == 404


@patch("main.httpx.get", side_effect=mock_httpx_get)
def test_update_order_status(mock_get):
    create = client.post("/orders", json={"user_id": 1, "product_id": 1, "quantity": 1})
    order_id = create.json()["id"]
    r = client.patch(f"/orders/{order_id}/status", json={"status": "confirmed"})
    assert r.status_code == 200
    assert r.json()["status"] == "confirmed"


def test_invalid_status_rejected():
    r = client.patch("/orders/1/status", json={"status": "flying"})
    assert r.status_code == 422


@patch("main.httpx.get")
def test_user_not_found_returns_422(mock_get):
    response = MagicMock()
    response.status_code = 404
    mock_get.return_value = response
    r = client.post("/orders", json={"user_id": 999, "product_id": 1, "quantity": 1})
    assert r.status_code == 422


@patch("main.httpx.get")
def test_insufficient_stock_returns_422(mock_get):
    low_stock_product = {**MOCK_PRODUCT, "stock": 1}
    def low_stock_get(url, **kwargs):
        resp = MagicMock()
        resp.status_code = 200
        resp.raise_for_status = MagicMock()
        if "/users/" in url:
            resp.json.return_value = MOCK_USER
        elif "/products/" in url:
            resp.json.return_value = low_stock_product
        return resp
    mock_get.side_effect = low_stock_get
    r = client.post("/orders", json={"user_id": 1, "product_id": 1, "quantity": 50})
    assert r.status_code == 422