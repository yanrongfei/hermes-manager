from sqlalchemy import Column, String, Integer, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    sender_id = Column(String, nullable=True)
    sender_type = Column(String, nullable=True)  # 'user'/'agent'
    sender_name = Column(String, nullable=True)
    content = Column(Text, nullable=False)
    content_type = Column(String, default="text")  # text/image/voice
    extra = Column(Text, nullable=True)  # JSON for image_url, voice_text etc.
    parent_id = Column(String, nullable=True)  # for threading/pipeline
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    room = relationship("Room", back_populates="messages")