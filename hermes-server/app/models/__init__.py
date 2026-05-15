# 导入所有模型以确保 SQLAlchemy 关系正确注册
from app.models.user import User
from app.models.room import Room, RoomMember
from app.models.message import Message
from app.models.machine import Machine
from app.models.agent import Agent, RoomAgent

__all__ = [
    "User",
    "Room",
    "RoomMember",
    "Message",
    "Machine",
    "Agent",
    "RoomAgent",
]