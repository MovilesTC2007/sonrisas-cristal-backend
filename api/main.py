from fastapi import FastAPI, Request

from routers import ALL_ROUTERS

from prometheus_fastapi_instrumentator import Instrumentator    

app = FastAPI(title="Sonrisas de Cristal API")


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    return response


for router in ALL_ROUTERS:
    app.include_router(router)

Instrumentator(
    should_group_status_codes=False,
    should_ignore_untemplated=False,
    excluded_handlers=["/metrics"],
).instrument(app).expose(app, include_in_schema=False)