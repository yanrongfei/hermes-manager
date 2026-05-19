#!/usr/bin/env python
"""
初始化脚本 - 创建默认管理员账户
"""
import asyncio
import sys
from app.database import init_db, get_session_maker
from app.services.auth import AuthService
# 导入所有模型以确保 SQLAlchemy 关系正确注册
from app.models import User, Room, RoomMember, Message, Machine, Agent, RoomAgent

async def create_default_admin():
    """创建默认管理员账户"""
    await init_db()
    
    async with get_session_maker()() as db:
        service = AuthService(db)
        
        # 检查是否已存在 admin 用户
        existing_user = await service.get_user_by_username("admin")
        if existing_user:
            print("✅ 管理员账户已存在")
            return
        
        # 创建管理员账户
        try:
            user = await service.create_user("admin", "admin123")
            print(f"✅ 管理员账户创建成功!")
            print(f"   用户名: admin")
            print(f"   密码: admin123")
            print(f"   用户ID: {user.id}")
        except Exception as e:
            print(f"❌ 创建管理员账户失败: {e}")
            sys.exit(1)

if __name__ == "__main__":
    print("🔧 开始初始化数据库...")
    asyncio.run(create_default_admin())
    print("✨ 初始化完成!")
