from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from enum import Enum

class OrderStatus(str, Enum):
    pending   = "pending"
    confirmed = "confirmed"
    shipped   = "shipped"
    delivered = "delivered"
    cancelled = "cancelled"

class OrderCreate(BaseModel):
    user_id: int
    product_id: int
    quantity: int = Field(default=1, ge=1)

class OrderStatusUpdate(BaseModel):
    status: OrderStatus

class OrderResponse(BaseModel):
    id: int
    user_id: int
    product_id: int
    quantity: int
    total_price: float
    status: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True