from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Machine(Base):
    __tablename__ = "machines"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=True)
    address = Column(String, nullable=False)  # IP:Port
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    user = relationship("User", back_populates="machines")
    agents = relationship("Agent", back_populates="machine")
