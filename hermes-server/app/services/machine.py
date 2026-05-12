from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.machine import Machine


class MachineService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_machine(
        self, user_id: str, address: str, name: Optional[str] = None
    ) -> Machine:
        machine = Machine(user_id=user_id, address=address, name=name)
        self.db.add(machine)
        await self.db.commit()
        await self.db.refresh(machine)
        return machine

    async def get_machine(self, machine_id: str, user_id: str) -> Optional[Machine]:
        result = await self.db.execute(
            select(Machine).where(Machine.id == machine_id, Machine.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_user_machines(self, user_id: str) -> List[Machine]:
        result = await self.db.execute(
            select(Machine).where(Machine.user_id == user_id)
        )
        return list(result.scalars().all())

    async def update_machine(
        self, machine_id: str, user_id: str, name: Optional[str] = None
    ) -> Optional[Machine]:
        machine = await self.get_machine(machine_id, user_id)
        if not machine:
            return None
        if name is not None:
            machine.name = name
        await self.db.commit()
        await self.db.refresh(machine)
        return machine

    async def delete_machine(self, machine_id: str, user_id: str) -> bool:
        machine = await self.get_machine(machine_id, user_id)
        if not machine:
            return False
        await self.db.delete(machine)
        await self.db.commit()
        return True
