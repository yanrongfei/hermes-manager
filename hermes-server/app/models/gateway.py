import time
from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base


class Gateway(Base):
    __tablename__ = "gateways"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=True)
    address = Column(String, nullable=False)
    api_key = Column(String, nullable=True)
    status = Column(String, default="unknown")
    last_seen = Column(Integer, nullable=True)
    created_at = Column(Integer, default=lambda: int(time.time()))

    user = relationship("User", back_populates="gateways")
    profiles = relationship("Profile", back_populates="gateway", cascade="all, delete-orphan")
