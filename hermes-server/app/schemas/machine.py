from pydantic import BaseModel, Field
from typing import Optional

class MachineCreate(BaseModel):
    name: Optional[str] = None
    address: str = Field(..., pattern=r"^\d+\.\d+\.\d+\.\d+:\d+$")

class MachineUpdate(BaseModel):
    name: Optional[str] = None

class MachineResponse(BaseModel):
    id: str
    name: Optional[str]
    address: str
    created_at: int

    class Config:
        from_attributes = True
