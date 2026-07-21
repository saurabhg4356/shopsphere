import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import sys, os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app
from database import Base, get_db

# Use in-memory SQLite for tests — fast, no external DB needed
TEST_DB = "sqlite:///./test_users.db"
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
    assert r.json()["status"] == "ok"
    assert r.json()["service"] == "user-service"


def test_create_user():
    r = client.post("/users", json={"name": "Priya Sharma", "email": "priya@test.dev"})
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Priya Sharma"
    assert data["email"] == "priya@test.dev"
    assert "id" in data


def test_list_users():
    r = client.get("/users")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_get_user_by_id():
    # Create first
    create = client.post("/users", json={"name": "Raj Kumar", "email": "raj@test.dev"})
    user_id = create.json()["id"]
    # Then fetch
    r = client.get(f"/users/{user_id}")
    assert r.status_code == 200
    assert r.json()["email"] == "raj@test.dev"


def test_get_user_not_found():
    r = client.get("/users/99999")
    assert r.status_code == 404


def test_duplicate_email_returns_409():
    client.post("/users", json={"name": "User A", "email": "duplicate@test.dev"})
    r = client.post("/users", json={"name": "User B", "email": "duplicate@test.dev"})
    assert r.status_code == 409


def test_invalid_email_rejected():
    r = client.post("/users", json={"name": "Bad User", "email": "not-an-email"})
    assert r.status_code == 422