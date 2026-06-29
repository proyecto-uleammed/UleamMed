from pydantic import BaseModel, ConfigDict, Field, field_validator


class UserBase(BaseModel):
    """Campos compartidos entre crear, leer y actualizar usuarios."""

    email: str = Field(..., min_length=5, max_length=255, examples=["usuario@uleam.edu.ec"])
    full_name: str | None = Field(default=None, max_length=255, examples=["Maria Zambrano"])

    @field_validator("email")
    @classmethod
    def validar_email(cls, value: str) -> str:
        """Normaliza el correo y valida una estructura minima."""
        email = value.strip().lower()
        if "@" not in email or "." not in email.rsplit("@", maxsplit=1)[-1]:
            raise ValueError("Debe ingresar un correo electronico valido")
        return email


class UserCreate(UserBase):
    """Datos que la app envia para registrar una cuenta."""

    password: str = Field(..., min_length=8, max_length=128, examples=["clave-segura-123"])


class UserUpdate(BaseModel):
    """Datos permitidos para actualizar el perfil propio."""

    full_name: str | None = Field(default=None, max_length=255, examples=["Maria Zambrano"])


class UserRead(UserBase):
    """Respuesta publica de usuario; no expone el hash de contrasena."""

    id: int
    is_active: bool

    # Permite convertir modelos SQLAlchemy directamente a respuesta Pydantic.
    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    """Credenciales para iniciar sesion."""

    email: str = Field(..., examples=["usuario@uleam.edu.ec"])
    password: str = Field(..., examples=["clave-segura-123"])


class RefreshRequest(BaseModel):
    """Token largo usado para solicitar un access token nuevo."""

    refresh_token: str


class TokenPair(BaseModel):
    """Respuesta del login con tokens de acceso y renovacion."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessToken(BaseModel):
    """Respuesta usada cuando solo se devuelve un access token nuevo."""

    access_token: str
    token_type: str = "bearer"
