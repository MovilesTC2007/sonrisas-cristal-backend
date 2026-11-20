"""Replaces the old /auth-check debug endpoint (removed during the
temp-salt-pepper merge): this logic has no business being a live,
unauthenticated HTTP route that creates/deletes real rows, so it lives
here as an integration test against the SQL auth functions instead."""

import uuid

PASSWORD = "password123"
WRONG_PASSWORD = "password121"


def _create_test_user(cur, email: str) -> int:
    cur.execute(
        "SELECT add_user(%s, %s, %s, %s, %s, %s, %s, %s)",
        (1, "Authentication", "Test", PASSWORD, email, 1, 1, True),
    )
    return cur.fetchone()[0]


def test_authenticate_accepts_correct_password_and_rejects_wrong_one(db_conn):
    email = f"authtest-{uuid.uuid4().hex}@example.com"
    with db_conn.cursor() as cur:
        try:
            user_id = _create_test_user(cur, email)

            cur.execute("SELECT password_hash FROM users WHERE user_id = %s", (user_id,))
            stored_hash = cur.fetchone()[0]

            cur.execute("SELECT authenticate(%s, %s)", (email, PASSWORD))
            ok_id = cur.fetchone()[0]
            cur.execute("SELECT authenticate(%s, %s)", (email, WRONG_PASSWORD))
            bad_id = cur.fetchone()[0]
        finally:
            cur.execute("DELETE FROM users WHERE email = %s", (email,))
            db_conn.commit()

    assert ok_id == user_id
    assert bad_id is None

    # bcrypt layout: $2a$ (4) | cost 12 (2) | $ (1) | salt (22) | hash (31) = 60
    assert stored_hash.startswith("$2")
    assert len(stored_hash) == 60
    assert PASSWORD not in stored_hash
