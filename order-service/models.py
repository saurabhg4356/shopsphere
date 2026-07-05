
from sqlalchemy import Column, Integer, Float, String, DateTime
from sqlalchemy.sql import func
from database import Base

class Order(Base):
    __tablename__ = "orders"

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, nullable=False, index=True)
    product_id  = Column(Integer, nullable=False, index=True)
    quantity    = Column(Integer, nullable=False, default=1)
    total_price = Column(Float, nullable=False)
    status      = Column(String(20), default="pending")
    created_at  = Column(DateTime(timezone=True), server_default=func.now())
    updated_at  = Column(DateTime(timezone=True), onupdate=func.now())