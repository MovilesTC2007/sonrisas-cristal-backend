import os

import psycopg
from fastapi import HTTPException
from psycopg import errors as pgerr
from psycopg.rows import dict_row

DATABASE_URL = os.environ.get("DATABASE_URL")

# Never send these columns to the client, even if a SQL function returns them, defense in depth
SECRET_FIELDS = {"password_hash"} 


def call(fn: str, *args) -> list[dict]:
    placeholders = ", ".join(["%s"] * len(args))
    try:
        with psycopg.connect(
            DATABASE_URL, row_factory=dict_row, connect_timeout=5
        ) as conn, conn.cursor() as cur:
            cur.execute(f"SELECT * FROM {fn}({placeholders})", args)
            rows = cur.fetchall()
    except pgerr.UniqueViolation:
        raise HTTPException(status_code=409, detail="Registro duplicado")
    except (
        pgerr.ForeignKeyViolation,
        pgerr.CheckViolation,
        pgerr.NotNullViolation,
        pgerr.InvalidTextRepresentation,
    ):
        raise HTTPException(status_code=400, detail="Datos inválidos")
    except pgerr.RaiseException as e:
        raise HTTPException(status_code=400, detail=e.diag.message_primary or "Solicitud rechazada")
    except psycopg.OperationalError:
        raise HTTPException(status_code=503, detail="Base de datos no disponible")
    except psycopg.Error:
        raise HTTPException(status_code=500, detail="Error interno")
    return [{k: v for k, v in r.items() if k not in SECRET_FIELDS} for r in rows]


def many(fn: str, *args) -> list[dict]:
    return call(fn, *args)


def one(fn: str, *args, status: int = 404, detail: str = "No encontrado") -> dict:
    rows = call(fn, *args)
    if not rows or all(v is None for v in rows[0].values()):
        raise HTTPException(status_code=status, detail=detail)
    return rows[0]
