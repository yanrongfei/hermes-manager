from sqlalchemy import Column, String, Integer, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Agent(Base):
    __tablename__ = "agents"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    machine_id = Column(String, ForeignKey("machines.id"), nullable=False)
    remote_id = Column(String, nullable=False)  # ID on Hermes Gateway
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    avatar = Column(String, nullable=True)
    profile = Column(String, nullable=True)
    invited = Column(Boolean, default=False)
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    machine = relationship("Machine", back_populates="agents")
    rooms = relationship("RoomAgent", back_populates="agent")

class RoomAgent(Base):
    __tablename__ = "room_agents"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    agent_id = Column(String, ForeignKey("agents.id"), nullable=False)
    joined_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    room = relationship("Room", back_populates="agents")
    agent = relationship("Agent", back_populates="rooms")
