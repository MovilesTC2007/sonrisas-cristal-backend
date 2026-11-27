from fastapi import FastAPI, Request

from routers import ALL_ROUTERS

app = FastAPI(title="Sonrisas de Cristal API")


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    return response


for router in ALL_ROUTERS:
    app.include_router(router)
