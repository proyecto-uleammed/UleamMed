"""Servicio demo para el modulo de medicamentos.

Estas funciones usan memoria temporal para el prototipo. Cuando el modulo de
base de datos este listo, este archivo debe cambiarse por consultas a tablas
reales de medicamentos, horarios y tomas del paciente.
"""

from copy import deepcopy
from threading import Lock

from backend.schemas.medication import MedicationRead


_DEMO_MEDICATIONS = [
    MedicationRead(id="metformina", name="Metformina", dose="500 mg", time="08:00", taken=True),
    MedicationRead(id="losartan", name="Losartán", dose="50 mg", time="08:00", taken=True),
    MedicationRead(id="omeprazol", name="Omeprazol", dose="20 mg", time="14:00", taken=False),
    MedicationRead(id="atorvastatina", name="Atorvastatina", dose="10 mg", time="20:00", taken=False),
]

_medications_by_user: dict[int, list[MedicationRead]] = {}
_lock = Lock()


def listar_medicamentos_usuario(user_id: int) -> list[MedicationRead]:
    """Devuelve los medicamentos demo del usuario autenticado."""
    with _lock:
        medicamentos = _medications_by_user.setdefault(user_id, deepcopy(_DEMO_MEDICATIONS))
        return [medicamento.model_copy() for medicamento in medicamentos]


def marcar_medicamento_tomado(user_id: int, medication_id: str) -> MedicationRead | None:
    """Marca como tomado un medicamento del usuario."""
    with _lock:
        medicamentos = _medications_by_user.setdefault(user_id, deepcopy(_DEMO_MEDICATIONS))
        for medicamento in medicamentos:
            if medicamento.id == medication_id:
                medicamento.taken = True
                return medicamento.model_copy()

    return None


def contar_medicamentos_tomados(user_id: int) -> tuple[int, int]:
    """Cuenta medicamentos tomados y total programado."""
    medicamentos = listar_medicamentos_usuario(user_id)
    return sum(1 for medicamento in medicamentos if medicamento.taken), len(medicamentos)
