from pydantic import BaseModel, ConfigDict, Field, field_validator

from backend.core.roles import PublicAccountType, UserRole


class UserBase(BaseModel):
    """Campos compartidos entre crear, leer y actualizar usuarios."""

    email: str = Field(..., min_length=5, max_length=255, examples=["usuario@uleam.edu.ec"])
    full_name: str | None = Field(default=None, max_length=255, examples=["Maria Zambrano"])

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        """Normaliza el correo y valida una estructura minima."""
        email = value.strip().lower()
        if "@" not in email or "." not in email.rsplit("@", maxsplit=1)[-1]:
            raise ValueError("Debe ingresar un correo electronico valido")
        return email


class UserCreate(UserBase):
    """Datos que la app envia para registrar una cuenta."""

    password: str = Field(..., min_length=8, max_length=128, examples=["clave-segura-123"])
    account_type: PublicAccountType = PublicAccountType.PATIENT
    model_config = ConfigDict(extra="forbid")


class UserUpdate(BaseModel):
    """Datos permitidos para actualizar el perfil propio."""

    full_name: str | None = Field(default=None, max_length=255, examples=["Maria Zambrano"])


class UserRead(UserBase):
    """Respuesta publica de usuario; no expone el hash de contrasena."""

    id: int
    is_active: bool
    role: UserRole

    # Permite convertir modelos SQLAlchemy directamente a respuesta Pydantic.
    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    """Credenciales para iniciar sesion."""

    email: str = Field(..., examples=["usuario@uleam.edu.ec"])
    password: str = Field(..., examples=["clave-segura-123"])


class RefreshRequest(BaseModel):
    """Token largo usado para solicitar un access token nuevo."""

    refresh_token: str


class PasswordResetRequest(BaseModel):
    """Solicitud para enviar codigo de recuperacion."""

    email: str = Field(..., examples=["usuario@uleam.edu.ec"])

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        email = value.strip().lower()
        if "@" not in email or "." not in email.rsplit("@", maxsplit=1)[-1]:
            raise ValueError("Debe ingresar un correo electronico valido")
        return email


class PasswordResetConfirm(BaseModel):
    """Datos necesarios para cambiar contrasena con codigo temporal."""

    email: str = Field(..., examples=["usuario@uleam.edu.ec"])
    code: str = Field(..., min_length=6, max_length=6, examples=["123456"])
    new_password: str = Field(..., min_length=8, max_length=128, examples=["nueva-clave-segura-123"])

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        email = value.strip().lower()
        if "@" not in email or "." not in email.rsplit("@", maxsplit=1)[-1]:
            raise ValueError("Debe ingresar un correo electronico valido")
        return email

    @field_validator("code")
    @classmethod
    def validate_code(cls, value: str) -> str:
        code = value.strip()
        if not code.isdigit():
            raise ValueError("El codigo debe tener 6 digitos")
        return code


class MessageResponse(BaseModel):
    """Respuesta generica para acciones sin datos sensibles."""

    message: str


class TokenPair(BaseModel):
    """Respuesta del login con tokens de acceso y renovacion."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessToken(BaseModel):
    """Respuesta usada cuando solo se devuelve un access token nuevo."""

    access_token: str
    token_type: str = "bearer"
