"""Sync profiles and agents from a Hermes Gateway."""

from datetime import datetime
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.gateway import Gateway
from app.models.profile import Profile
from app.models.agent import Agent
from app.services.gateway_channel import GatewayChannel


class GatewaySyncService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def sync_gateway(self, gateway_id: str, user_id: str) -> dict:
        gateway = await self._get_gateway(gateway_id, user_id)
        if not gateway:
            return {"error": "Gateway not found"}

        channel = GatewayChannel(gateway)
        try:
            is_online = await channel.health_check()

            if not is_online:
                gateway.status = "offline"
                await self.db.commit()
                return {"status": "offline", "profiles_synced": 0, "agents_synced": 0}

            gateway.status = "online"
            gateway.last_seen = int(datetime.utcnow().timestamp())

            # Fetch agents from gateway — each model entry represents a profile+agent
            agents_data = await channel.list_agents()
            now = int(datetime.utcnow().timestamp())

            profiles_synced = 0
            agents_synced = 0

            for agent_data in agents_data:
                profile_name = agent_data.get("profile_name", "default")
                profile = await self._upsert_profile(
                    gateway_id=gateway_id,
                    remote_name=profile_name,
                    model=agent_data.get("model"),
                    provider=agent_data.get("provider"),
                    description=agent_data.get("description"),
                    synced_at=now,
                )
                profiles_synced += 1

                await self._upsert_agent(
                    profile_id=profile.id,
                    remote_id=agent_data.get("remote_id", agent_data.get("id", "")),
                    name=agent_data.get("name", "Agent"),
                    description=agent_data.get("description"),
                    avatar=agent_data.get("avatar"),
                )
                agents_synced += 1

            await self.db.commit()

            return {
                "status": "online",
                "profiles_synced": profiles_synced,
                "agents_synced": agents_synced,
            }
        finally:
            await channel.close()

    async def _get_gateway(self, gateway_id: str, user_id: str) -> Optional[Gateway]:
        result = await self.db.execute(
            select(Gateway).where(Gateway.id == gateway_id, Gateway.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def _upsert_profile(
        self,
        gateway_id: str,
        remote_name: str,
        model: Optional[str] = None,
        provider: Optional[str] = None,
        description: Optional[str] = None,
        synced_at: Optional[int] = None,
    ) -> Profile:
        result = await self.db.execute(
            select(Profile).where(
                Profile.gateway_id == gateway_id,
                Profile.remote_name == remote_name,
            )
        )
        profile = result.scalar_one_or_none()

        if profile:
            if model is not None:
                profile.model = model
            if provider is not None:
                profile.provider = provider
            if description is not None:
                profile.description = description
            if synced_at is not None:
                profile.synced_at = synced_at
        else:
            profile = Profile(
                gateway_id=gateway_id,
                remote_name=remote_name,
                model=model,
                provider=provider,
                description=description,
                synced_at=synced_at,
            )
            self.db.add(profile)

        await self.db.flush()
        if not profile.id:
            await self.db.refresh(profile)
        return profile

    async def _upsert_agent(
        self,
        profile_id: str,
        remote_id: str,
        name: str,
        description: Optional[str] = None,
        avatar: Optional[str] = None,
    ) -> Agent:
        result = await self.db.execute(
            select(Agent).where(
                Agent.profile_id == profile_id,
                Agent.remote_id == remote_id,
            )
        )
        agent = result.scalar_one_or_none()

        if agent:
            agent.name = name
            if description is not None:
                agent.description = description
            if avatar is not None:
                agent.avatar = avatar
        else:
            agent = Agent(
                profile_id=profile_id,
                remote_id=remote_id,
                name=name,
                description=description,
                avatar=avatar,
            )
            self.db.add(agent)

        await self.db.flush()
        return agent
