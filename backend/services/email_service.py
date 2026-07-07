from email.message import EmailMessage
import logging
import smtplib

from backend.core.config import settings
from backend.models.user import User


logger = logging.getLogger(__name__)


def send_welcome_email(user: User) -> None:
    """Envia o registra el correo de bienvenida posterior al registro."""
    name = user.full_name or user.email
    subject = "Tu cuenta UleamMed fue creada"
    body = (
        f"Hola {name},\n\n"
        "Tu cuenta en UleamMed fue creada correctamente.\n"
        "Ya puedes iniciar sesión y gestionar tu salud diaria desde la aplicación.\n\n"
        "Gracias por confiar en UleamMed.\n\n"
        "Equipo UleamMed"
    )
    _send_email(recipient=user.email, subject=subject, body=body)


def send_password_reset_email(user: User, code: str, expiration_minutes: int) -> None:
    """Envia o registra el codigo temporal para restablecer contrasena."""
    name = user.full_name or user.email
    subject = "Código para restablecer tu contraseña de UleamMed"
    body = (
        f"Hola {name},\n\n"
        "Recibimos una solicitud para restablecer la contraseña de tu cuenta.\n\n"
        f"Código de recuperación: {code}\n"
        f"Este código vence en {expiration_minutes} minutos.\n\n"
        "Si no solicitaste este cambio, puedes ignorar este correo.\n\n"
        "Equipo UleamMed"
    )
    _send_email(recipient=user.email, subject=subject, body=body)


def send_password_updated_email(user: User) -> None:
    """Envia confirmacion cuando la contrasena fue restablecida."""
    name = user.full_name or user.email
    subject = "Tu contraseña de UleamMed fue actualizada"
    body = (
        f"Hola {name},\n\n"
        "La contraseña de tu cuenta UleamMed fue restablecida correctamente.\n"
        "Si realizaste este cambio, no necesitas hacer nada más.\n\n"
        "Si no reconoces esta acción, contacta al equipo de soporte de UleamMed.\n\n"
        "Equipo UleamMed"
    )
    _send_email(recipient=user.email, subject=subject, body=body)


def _send_email(recipient: str, subject: str, body: str) -> None:
    if not settings.SMTP_HOST:
        logger.warning(
            "Correo UleamMed en modo desarrollo para %s | asunto=%s | cuerpo=%s",
            recipient,
            subject,
            body.replace("\n", " "),
        )
        return

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    message["To"] = recipient
    message.set_content(body)

    try:
        smtp_class = smtplib.SMTP_SSL if settings.SMTP_USE_TLS and settings.SMTP_PORT == 465 else smtplib.SMTP
        with smtp_class(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10) as smtp:
            if settings.SMTP_USE_TLS and settings.SMTP_PORT != 465:
                smtp.starttls()
            if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
                smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            smtp.send_message(message)
            logger.info("Correo UleamMed enviado a %s | asunto=%s", recipient, subject)
    except Exception:
        logger.exception("No se pudo enviar correo UleamMed a %s", recipient)
