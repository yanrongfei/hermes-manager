from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.database import get_db
from app.core.deps import get_current_user
from app.schemas.machine import MachineCreate, MachineUpdate, MachineResponse
from app.services.machine import MachineService

router = APIRouter(prefix="/machines", tags=["machines"])


@router.get("", response_model=List[MachineResponse])
async def list_machines(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = MachineService(db)
    return await service.get_user_machines(current_user.id)


@router.post("", response_model=MachineResponse, status_code=status.HTTP_201_CREATED)
async def create_machine(
    data: MachineCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = MachineService(db)
    return await service.create_machine(current_user.id, data.address, data.name)


@router.get("/{machine_id}", response_model=MachineResponse)
async def get_machine(
    machine_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = MachineService(db)
    machine = await service.get_machine(machine_id, current_user.id)
    if not machine:
        raise HTTPException(status_code=404, detail="Machine not found")
    return machine


@router.put("/{machine_id}", response_model=MachineResponse)
async def update_machine(
    machine_id: str,
    data: MachineUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = MachineService(db)
    machine = await service.update_machine(machine_id, current_user.id, data.name)
    if not machine:
        raise HTTPException(status_code=404, detail="Machine not found")
    return machine


@router.delete("/{machine_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_machine(
    machine_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = MachineService(db)
    success = await service.delete_machine(machine_id, current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Machine not found")
