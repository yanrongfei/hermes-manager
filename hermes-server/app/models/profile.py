import time
from sqlalchemy import Column, String, Integer, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base


class Profile(Base):
    __tablename__ = "profiles"
    __table_args__ = (
        UniqueConstraint("gateway_id", "remote_name", name="uq_profile_gateway_name"),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    gateway_id = Column(String, ForeignKey("gateways.id", ondelete="CASCADE"), nullable=False)
    remote_name = Column(String, nullable=False)
    alias = Column(String, nullable=True)
    model = Column(String, nullable=True)
    provider = Column(String, nullable=True)
    skills = Column(Integer, default=0)
    description = Column(String, nullable=True)
    synced_at = Column(Integer, nullable=True)
    created_at = Column(Integer, default=lambda: int(time.time()))

    gateway = relationship("Gateway", back_populates="profiles")
    agents = relationship("Agent", back_populates="profile", cascade="all, delete-orphan")
