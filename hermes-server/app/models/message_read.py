import time
from sqlalchemy import Column, String, Integer, ForeignKey, UniqueConstraint
from datetime import datetime
import uuid
from app.database import Base


class MessageRead(Base):
    __tablename__ = "message_reads"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    last_read_message_id = Column(String, nullable=True)
    last_read_at = Column(Integer, default=lambda: int(time.time()))

    __table_args__ = (
        UniqueConstraint("user_id", "room_id", name="uq_message_read_user_room"),
    )
