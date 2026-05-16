from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.agent import Agent, RoomAgent
from app.models.profile import Profile
from app.models.gateway import Gateway


class AgentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_agent(self, agent_id: str) -> Optional[Agent]:
        result = await self.db.execute(select(Agent).where(Agent.id == agent_id))
        return result.scalar_one_or_none()

    async def get_user_agents(self, user_id: str) -> List[Agent]:
        result = await self.db.execute(
            select(Agent)
            .join(Profile)
            .join(Gateway)
            .where(Gateway.user_id == user_id)
        )
        return list(result.scalars().all())

    async def get_profile_agents(self, profile_id: str) -> List[Agent]:
        result = await self.db.execute(
            select(Agent).where(Agent.profile_id == profile_id)
        )
        return list(result.scalars().all())

    async def delete_agent(self, agent_id: str, user_id: str) -> bool:
        result = await self.db.execute(
            select(Agent)
            .join(Profile)
            .join(Gateway)
            .where(Agent.id == agent_id, Gateway.user_id == user_id)
        )
        agent = result.scalar_one_or_none()
        if not agent:
            return False
        await self.db.delete(agent)
        await self.db.commit()
        return True

    async def invite_agent(self, agent_id: str, user_id: str) -> Optional[Agent]:
        result = await self.db.execute(
            select(Agent)
            .join(Profile)
            .join(Gateway)
            .where(Agent.id == agent_id, Gateway.user_id == user_id)
        )
        agent = result.scalar_one_or_none()
        if not agent:
            return None
        agent.invited = True
        await self.db.commit()
        await self.db.refresh(agent)
        return agent

    async def add_agent_to_room(self, room_id: str, agent_id: str) -> RoomAgent:
        room_agent = RoomAgent(room_id=room_id, agent_id=agent_id)
        self.db.add(room_agent)
        await self.db.commit()
        await self.db.refresh(room_agent)
        return room_agent

    async def get_room_agents(self, room_id: str) -> List[Agent]:
        result = await self.db.execute(
            select(Agent).join(RoomAgent).where(RoomAgent.room_id == room_id)
        )
        return list(result.scalars().all())

    async def remove_agent_from_room(self, room_id: str, agent_id: str) -> bool:
        result = await self.db.execute(
            select(RoomAgent).where(
                RoomAgent.room_id == room_id,
                RoomAgent.agent_id == agent_id,
            )
        )
        room_agent = result.scalar_one_or_none()
        if not room_agent:
            return False
        await self.db.delete(room_agent)
        await self.db.commit()
        return True
