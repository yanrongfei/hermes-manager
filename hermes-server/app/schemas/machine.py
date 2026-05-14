from pydantic import BaseModel, Field
from typing import Optional

class MachineCreate(BaseModel):
    name: Optional[str] = None
    address: str = Field(..., description="Gateway address: IP:Port or hostname:Port")

class MachineUpdate(BaseModel):
    name: Optional[str] = None

class MachineResponse(BaseModel):
    id: str
    name: Optional[str]
    address: str
    created_at: int

    class Config:
        from_attributes = True
