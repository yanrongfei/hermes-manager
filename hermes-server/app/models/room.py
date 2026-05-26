import time
from sqlalchemy import Column, String, Integer, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Room(Base):
    __tablename__ = "rooms"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    avatar = Column(String, nullable=True)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False)
    mode = Column(String, default="broadcast")  # broadcast/mention/router/pipeline
    trigger_tokens = Column(Integer, default=100000)
    max_history_tokens = Column(Integer, default=32000)
    tail_message_count = Column(Integer, default=20)
    invite_code = Column(String, nullable=True)
    agent_id = Column(String, nullable=True)  # For 1:1 chats: the associated agent ID
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True)  # For 1:1 chats
    created_at = Column(Integer, default=lambda: int(time.time()))

    # Relationships
    owner = relationship("User", foreign_keys=[owner_id])
    members = relationship("RoomMember", back_populates="room")
    agents = relationship("RoomAgent", back_populates="room")
    messages = relationship("Message", back_populates="room")

class RoomMember(Base):
    __tablename__ = "room_members"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    role = Column(String, default="member")  # owner/admin/member
    joined_at = Column(Integer, default=lambda: int(time.time()))

    # Relationships
    room = relationship("Room", back_populates="members")
    user = relationship("User", back_populates="rooms")