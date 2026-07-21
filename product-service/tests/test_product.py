import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import sys, os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app
from database import Base, get_db

TEST_DB = "sqlite:///./test_products.db"
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


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["service"] == "product-service"


def test_create_product():
    r = client.post("/products", json={
        "name": "Wireless Headphones",
        "description": "Noise-cancelling",
        "price": 2999.99,
        "stock": 50
    })
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Wireless Headphones"
    assert data["price"] == 2999.99
    assert data["stock"] == 50


def test_list_products():
    r = client.get("/products")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_get_product_by_id():
    create = client.post("/products", json={"name": "Laptop Stand", "price": 1499.0, "stock": 20})
    pid = create.json()["id"]
    r = client.get(f"/products/{pid}")
    assert r.status_code == 200
    assert r.json()["name"] == "Laptop Stand"


def test_get_product_not_found():
    r = client.get("/products/99999")
    assert r.status_code == 404


def test_update_product_stock():
    create = client.post("/products", json={"name": "USB Hub", "price": 999.0, "stock": 10})
    pid = create.json()["id"]
    r = client.patch(f"/products/{pid}", json={"stock": 5})
    assert r.status_code == 200
    assert r.json()["stock"] == 5


def test_invalid_price_rejected():
    r = client.post("/products", json={"name": "Bad Product", "price": -100, "stock": 10})
    assert r.status_code == 422


def test_price_filter():
    client.post("/products", json={"name": "Cheap Item", "price": 99.0, "stock": 5})
    client.post("/products", json={"name": "Expensive Item", "price": 9999.0, "stock": 5})
    r = client.get("/products?max_price=500")
    products = r.json()
    assert all(p["price"] <= 500 for p in products)