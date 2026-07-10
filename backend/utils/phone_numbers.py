import re

_PHONE_DIGITS = re.compile(r"\D")


def normalize_ecuador_phone(value: str) -> str:
    cleaned = value.strip()
    digits = _PHONE_DIGITS.sub("", cleaned)
    if not digits:
        raise ValueError("Telefono invalido")

    if cleaned.startswith("+593") or digits.startswith("593"):
        national = digits[3:]
    elif digits.startswith("0"):
        national = digits[1:]
    else:
        national = digits

    if len(national) < 8 or len(national) > 9:
        raise ValueError("Telefono invalido")
    return f"+593{national}"
