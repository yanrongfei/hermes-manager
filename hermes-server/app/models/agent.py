from sqlalchemy import Column, String, Integer, Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base


class Agent(Base):
    __tablename__ = "agents"
    __table_args__ = (
        UniqueConstraint("profile_id", "remote_id", name="uq_agent_profile_remote"),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    remote_id = Column(String, nullable=False)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    avatar = Column(String, nullable=True)
    invited = Column(Boolean, default=False)
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    profile = relationship("Profile", back_populates="agents")
    rooms = relationship("RoomAgent", back_populates="agent")


class RoomAgent(Base):
    __tablename__ = "room_agents"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    agent_id = Column(String, ForeignKey("agents.id"), nullable=False)
    joined_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    room = relationship("Room", back_populates="agents")
    agent = relationship("Agent", back_populates="rooms")
