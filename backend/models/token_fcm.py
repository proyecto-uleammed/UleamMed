# backend/models/token_fcm.py
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class TokenFcm(Base):
    __tablename__ = "token_fcm"

    id_token: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_usuario: Mapped[int] = mapped_column(ForeignKey("usuario.id_usuario"), nullable=False)

    token: Mapped[str] = mapped_column(String(500), unique=True, nullable=False)
    fecha_registro: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)