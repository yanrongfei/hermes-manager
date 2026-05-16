from sqlalchemy import Column, String, Integer, Boolean, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))
    multi_device = Column(Boolean, default=False)

    # Relationships
    rooms = relationship("RoomMember", back_populates="user")
    gateways = relationship("Gateway", back_populates="user")