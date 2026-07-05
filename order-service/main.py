import os
import httpx
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
import models, schemas
from database import engine, get_db

models.Base.metadata.create_all(bind=engine)

USER_SERVICE_URL    = os.getenv("USER_SERVICE_URL",    "http://127.0.0.1:8001")
PRODUCT_SERVICE_URL = os.getenv("PRODUCT_SERVICE_URL", "http://127.0.0.1:8002")

app = FastAPI(title="Order Service", version="1.0.0")


@app.get("/")
def root():
    return {"message": "Order service is running", "docs": "/docs"}


def get_user_or_404(user_id: int) -> dict:
    try:
        r = httpx.get(f"{USER_SERVICE_URL}/users/{user_id}", timeout=3.0)
        if r.status_code == 404:
            raise HTTPException(status_code=422, detail=f"User {user_id} does not exist")
        r.raise_for_status()
        return r.json()
    except httpx.RequestError:
        raise HTTPException(status_code=503, detail="User service unreachable")

def get_product_or_404(product_id: int) -> dict:
    try:
        r = httpx.get(f"{PRODUCT_SERVICE_URL}/products/{product_id}", timeout=3.0)
        if r.status_code == 404:
            raise HTTPException(status_code=422, detail=f"Product {product_id} does not exist")
        r.raise_for_status()
        return r.json()
    except httpx.RequestError:
        raise HTTPException(status_code=503, detail="Product service unreachable")


@app.get("/health")
def health():
    return {"status": "ok", "service": "order-service"}


@app.post("/orders", response_model=schemas.OrderResponse, status_code=201)
def create_order(payload: schemas.OrderCreate, db: Session = Depends(get_db)):
    get_user_or_404(payload.user_id)
    product = get_product_or_404(payload.product_id)

    if product["stock"] < payload.quantity:
        raise HTTPException(
            status_code=422,
            detail=f"Not enough stock. Requested: {payload.quantity}, Available: {product['stock']}"
        )

    order = models.Order(
        user_id=payload.user_id,
        product_id=payload.product_id,
        quantity=payload.quantity,
        total_price=round(product["price"] * payload.quantity, 2),
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return order


@app.get("/orders", response_model=List[schemas.OrderResponse])
def list_orders(user_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(models.Order)
    if user_id:
        query = query.filter(models.Order.user_id == user_id)
    return query.all()


@app.get("/orders/{order_id}", response_model=schemas.OrderResponse)
def get_order(order_id: int, db: Session = Depends(get_db)):
    order = db.query(models.Order).filter(models.Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@app.patch("/orders/{order_id}/status", response_model=schemas.OrderResponse)
def update_order_status(order_id: int, payload: schemas.OrderStatusUpdate, db: Session = Depends(get_db)):
    order = db.query(models.Order).filter(models.Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    order.status = payload.status
    db.commit()
    db.refresh(order)
    return order