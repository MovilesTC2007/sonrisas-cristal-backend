from fastapi import FastAPI

from routers import ALL_ROUTERS

app = FastAPI(title="Sonrisas de Cristal API")

for router in ALL_ROUTERS:
    app.include_router(router)
