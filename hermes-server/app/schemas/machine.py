from pydantic import BaseModel, Field
from typing import Optional

class MachineCreate(BaseModel):
    name: Optional[str] = None
    address: str = Field(..., description="Gateway address: IP:Port or hostname:Port")
    api_key: Optional[str] = Field(None, description="Gateway API key (optional)")

class MachineUpdate(BaseModel):
    name: Optional[str] = None
    api_key: Optional[str] = None

class MachineResponse(BaseModel):
    id: str
    name: Optional[str]
    address: str
    api_key: Optional[str]
    created_at: int

    class Config:
        from_attributes = True
