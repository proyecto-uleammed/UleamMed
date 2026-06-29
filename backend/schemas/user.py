from pydantic import BaseModel, ConfigDict, Field, field_validator


class UserBase(BaseModel):
    email: str = Field(..., min_length=5, max_length=255, examples=["usuario@uleam.edu.ec"])
    full_name: str | None = Field(default=None, max_length=255, examples=["Maria Zambrano"])

    @field_validator("email")
    @classmethod
    def validar_email(cls, value: str) -> str:
        email = value.strip().lower()
        if "@" not in email or "." not in email.rsplit("@", maxsplit=1)[-1]:
            raise ValueError("Debe ingresar un correo electronico valido")
        return email


class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=128, examples=["clave-segura-123"])


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, max_length=255, examples=["Maria Zambrano"])


class UserRead(UserBase):
    id: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    email: str = Field(..., examples=["usuario@uleam.edu.ec"])
    password: str = Field(..., examples=["clave-segura-123"])


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessToken(BaseModel):
    access_token: str
    token_type: str = "bearer"
