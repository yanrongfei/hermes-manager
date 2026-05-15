from pydantic import BaseModel, Field
from typing import Optional


class MachineCreate(BaseModel):
    name: Optional[str] = None
    address: str = Field(..., description="Gateway address: IP:Port or local profile path")
    api_key: Optional[str] = Field(None, description="Gateway API key (optional)")
    mode: str = Field("http", description="Communication mode: http or local")
    profile_name: Optional[str] = Field(None, description="Local profile name")


class MachineUpdate(BaseModel):
    name: Optional[str] = None
    api_key: Optional[str] = None


class MachineResponse(BaseModel):
    id: str
    name: Optional[str]
    address: str
    api_key: Optional[str]
    mode: str
    profile_name: Optional[str]
    created_at: int

    class Config:
        from_attributes = True
