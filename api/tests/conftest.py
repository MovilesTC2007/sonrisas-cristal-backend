import os

import psycopg
import pytest

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://sonrisas_app:dev_only_password@localhost:5432/sonrisas_cristal")


@pytest.fixture
def db_conn():
    with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn:
        yield conn
