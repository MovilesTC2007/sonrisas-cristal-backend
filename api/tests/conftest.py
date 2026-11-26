import os
import sys
from pathlib import Path

# Import security.py/schemas.py as top-level modules the way the app does,
# regardless of where pytest is invoked from.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# security.py reads these at import time; the policy tests never touch a
# real database or issue a real token, so placeholder values are enough.
os.environ.setdefault("SECRET_KEY", "test-secret-not-for-prod")
os.environ.setdefault("ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "60")
os.environ.setdefault("DATABASE_URL", "postgresql://unused:unused@localhost:5432/unused")
