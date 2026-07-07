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
        "Ya puedes iniciar sesión y gestionar tu salud diaria desde la aplicación.\n\n"
        "Gracias por confiar en UleamMed.\n\n"
        "Equipo UleamMed"
    )
    _enviar_email(destinatario=usuario.email, asunto=asunto, cuerpo=cuerpo)


def enviar_correo_recuperacion(usuario: User, codigo: str, minutos_expiracion: int) -> None:
    """Envia o registra el codigo temporal para restablecer contrasena."""
    nombre = usuario.full_name or usuario.email
    asunto = "Código para restablecer tu contraseña de UleamMed"
    cuerpo = (
        f"Hola {nombre},\n\n"
        "Recibimos una solicitud para restablecer la contraseña de tu cuenta.\n\n"
        f"Código de recuperación: {codigo}\n"
        f"Este código vence en {minutos_expiracion} minutos.\n\n"
        "Si no solicitaste este cambio, puedes ignorar este correo.\n\n"
        "Equipo UleamMed"
    )
    _enviar_email(destinatario=usuario.email, asunto=asunto, cuerpo=cuerpo)


def enviar_correo_password_actualizado(usuario: User) -> None:
    """Envia confirmacion cuando la contrasena fue restablecida."""
    nombre = usuario.full_name or usuario.email
    asunto = "Tu contraseña de UleamMed fue actualizada"
    cuerpo = (
        f"Hola {nombre},\n\n"
        "La contraseña de tu cuenta UleamMed fue restablecida correctamente.\n"
        "Si realizaste este cambio, no necesitas hacer nada más.\n\n"
        "Si no reconoces esta acción, contacta al equipo de soporte de UleamMed.\n\n"
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
            logger.info("Correo UleamMed enviado a %s | asunto=%s", destinatario, asunto)
    except Exception:
        logger.exception("No se pudo enviar correo UleamMed a %s", destinatario)
