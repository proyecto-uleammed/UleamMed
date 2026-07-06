from email.message import EmailMessage
import logging
import smtplib

from backend.core.config import settings
from backend.models.user import User


logger = logging.getLogger(__name__)


def enviar_correo_bienvenida(usuario: User) -> None:
    """Envia o registra el correo de bienvenida posterior al registro."""
    nombre = usuario.full_name or usuario.email
    asunto = "Tu cuenta UleamMed fue creada"
    cuerpo = (
        f"Hola {nombre},\n\n"
        "Tu cuenta en UleamMed fue creada correctamente.\n"
        "Ya puedes iniciar sesion y gestionar tu salud diaria.\n\n"
        "Equipo UleamMed"
    )
    _enviar_email(destinatario=usuario.email, asunto=asunto, cuerpo=cuerpo)


def enviar_correo_recuperacion(usuario: User, codigo: str, minutos_expiracion: int) -> None:
    """Envia o registra el codigo temporal para restablecer contrasena."""
    nombre = usuario.full_name or usuario.email
    asunto = "Codigo para restablecer tu contrasena UleamMed"
    cuerpo = (
        f"Hola {nombre},\n\n"
        "Recibimos una solicitud para restablecer tu contrasena.\n"
        f"Tu codigo de recuperacion es: {codigo}\n"
        f"Este codigo vence en {minutos_expiracion} minutos.\n\n"
        "Si no solicitaste este cambio, puedes ignorar este correo.\n\n"
        "Equipo UleamMed"
    )
    _enviar_email(destinatario=usuario.email, asunto=asunto, cuerpo=cuerpo)


def _enviar_email(destinatario: str, asunto: str, cuerpo: str) -> None:
    if not settings.SMTP_HOST:
        logger.warning(
            "Correo UleamMed en modo desarrollo para %s | asunto=%s | cuerpo=%s",
            destinatario,
            asunto,
            cuerpo.replace("\n", " "),
        )
        return

    mensaje = EmailMessage()
    mensaje["Subject"] = asunto
    mensaje["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    mensaje["To"] = destinatario
    mensaje.set_content(cuerpo)

    try:
        smtp_class = smtplib.SMTP_SSL if settings.SMTP_USE_TLS and settings.SMTP_PORT == 465 else smtplib.SMTP
        with smtp_class(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10) as smtp:
            if settings.SMTP_USE_TLS and settings.SMTP_PORT != 465:
                smtp.starttls()
            if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
                smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            smtp.send_message(mensaje)
    except Exception:
        logger.exception("No se pudo enviar correo UleamMed a %s", destinatario)
