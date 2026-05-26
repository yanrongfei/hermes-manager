import time
from typing import List, Optional
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.gateway import Gateway
from app.models.profile import Profile
from app.models.agent import Agent


class GatewayService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_gateway(
        self, user_id: str, address: str, name: Optional[str] = None, api_key: Optional[str] = None
    ) -> Gateway:
        gateway = Gateway(user_id=user_id, address=address, name=name, api_key=api_key)
        self.db.add(gateway)
        await self.db.commit()
        await self.db.refresh(gateway)
        return gateway

    async def get_gateway(self, gateway_id: str, user_id: str) -> Optional[Gateway]:
        result = await self.db.execute(
            select(Gateway).where(Gateway.id == gateway_id, Gateway.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_user_gateways(self, user_id: str) -> List[dict]:
        result = await self.db.execute(
            select(Gateway).where(Gateway.user_id == user_id)
        )
        gateways = list(result.scalars().all())

        response = []
        for gw in gateways:
            profile_count = await self._count_profiles(gw.id)
            agent_count = await self._count_agents(gw.id)
            response.append(self._to_response(gw, profile_count, agent_count))
        return response

    async def update_gateway(
        self, gateway_id: str, user_id: str, name: Optional[str] = None, api_key: Optional[str] = None
    ) -> Optional[Gateway]:
        gateway = await self.get_gateway(gateway_id, user_id)
        if not gateway:
            return None
        if name is not None:
            gateway.name = name
        if api_key is not None:
            gateway.api_key = api_key
        await self.db.commit()
        await self.db.refresh(gateway)
        return gateway

    async def delete_gateway(self, gateway_id: str, user_id: str) -> bool:
        gateway = await self.get_gateway(gateway_id, user_id)
        if not gateway:
            return False
        await self.db.delete(gateway)
        await self.db.commit()
        return True

    async def update_status(self, gateway_id: str, status: str):
        gateway_result = await self.db.execute(
            select(Gateway).where(Gateway.id == gateway_id)
        )
        gateway = gateway_result.scalar_one_or_none()
        if gateway:
            gateway.status = status
            if status == "online":
                from datetime import datetime
                gateway.last_seen = int(time.time())
            await self.db.commit()

    async def _count_profiles(self, gateway_id: str) -> int:
        result = await self.db.execute(
            select(func.count(Profile.id)).where(Profile.gateway_id == gateway_id)
        )
        return result.scalar() or 0

    async def _count_agents(self, gateway_id: str) -> int:
        result = await self.db.execute(
            select(func.count(Agent.id))
            .join(Profile)
            .where(Profile.gateway_id == gateway_id)
        )
        return result.scalar() or 0

    def _to_response(self, gateway: Gateway, profile_count: int = 0, agent_count: int = 0) -> dict:
        return {
            "id": gateway.id,
            "name": gateway.name,
            "address": gateway.address,
            "api_key": gateway.api_key,
            "status": gateway.status or "unknown",
            "last_seen": gateway.last_seen,
            "created_at": gateway.created_at,
            "profile_count": profile_count,
            "agent_count": agent_count,
        }
