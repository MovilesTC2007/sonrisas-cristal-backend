import os

import psycopg
from fastapi import FastAPI, HTTPException

app = FastAPI()

DATABASE_URL = os.environ.get("DATABASE_URL")


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/health/db")
def health_db():
    try:
        with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        return {"status": "ok"}
    except psycopg.Error as e:
        raise HTTPException(status_code=503, detail=f"database unreachable: {e}") from e
