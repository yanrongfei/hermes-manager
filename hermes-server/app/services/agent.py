from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.agent import Agent, RoomAgent
from app.models.machine import Machine
from app.services.machine import MachineService


class AgentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_agent(
        self,
        machine_id: str,
        remote_id: str,
        name: str,
        user_id: str,
        description: Optional[str] = None,
        avatar: Optional[str] = None,
        profile: Optional[str] = None,
        invited: bool = False,
    ) -> Agent:
        machine_service = MachineService(self.db)
        machine = await machine_service.get_machine(machine_id, user_id)
        if not machine:
            raise ValueError("Machine not found")

        agent = Agent(
            machine_id=machine_id,
            remote_id=remote_id,
            name=name,
            description=description,
            avatar=avatar,
            profile=profile,
            invited=invited,
        )
        self.db.add(agent)
        await self.db.commit()
        await self.db.refresh(agent)
        return agent

    async def get_agent(self, agent_id: str) -> Optional[Agent]:
        result = await self.db.execute(select(Agent).where(Agent.id == agent_id))
        return result.scalar_one_or_none()

    async def get_user_agents(self, user_id: str) -> List[Agent]:
        result = await self.db.execute(
            select(Agent).join(Machine).where(Machine.user_id == user_id)
        )
        return list(result.scalars().all())

    async def get_machine_agents(
        self, machine_id: str, user_id: str
    ) -> List[Agent]:
        machine_service = MachineService(self.db)
        machine = await machine_service.get_machine(machine_id, user_id)
        if not machine:
            return []
        result = await self.db.execute(
            select(Agent).where(Agent.machine_id == machine_id)
        )
        return list(result.scalars().all())

    async def update_agent(
        self,
        agent_id: str,
        user_id: str,
        name: Optional[str] = None,
        description: Optional[str] = None,
        avatar: Optional[str] = None,
        profile: Optional[str] = None,
    ) -> Optional[Agent]:
        # Verify ownership
        result = await self.db.execute(
            select(Agent)
            .join(Machine)
            .where(Agent.id == agent_id, Machine.user_id == user_id)
        )
        agent = result.scalar_one_or_none()
        if not agent:
            return None
        if name is not None:
            agent.name = name
        if description is not None:
            agent.description = description
        if avatar is not None:
            agent.avatar = avatar
        if profile is not None:
            agent.profile = profile
        await self.db.commit()
        await self.db.refresh(agent)
        return agent

    async def delete_agent(self, agent_id: str, user_id: str) -> bool:
        result = await self.db.execute(
            select(Agent)
            .join(Machine)
            .where(Agent.id == agent_id, Machine.user_id == user_id)
        )
        agent = result.scalar_one_or_none()
        if not agent:
            return False
        await self.db.delete(agent)
        await self.db.commit()
        return True

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
