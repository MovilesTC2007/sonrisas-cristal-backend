## About

This system integrates the deployment and infrastructure supporting the mobile application [SonrisasDeCristal](https://github.com/MovilesTC2007/sonrisas-asistencia-android).

The system reinforces heavily the cibersecurity, observability, CI/CD and deployment.

## Run locally
Development settings are opt-in: the file `compose.dev.yml` is not loaded by
plain `docker compose up`. Include it explicitly to enable the source mount and
FastAPI development server. Nginx creates a self-signed certificate for local
use; browsers will warn that it is not publicly trusted.

```powershell
# Local development: starts the API, database, and Nginx with a local certificate.
docker compose -f compose.yml -f compose.dev.yml up --build db api nginx-tls
```

## Tech Stack
- Docker
- FastAPI
- Postgres
- Grafana & Prometheus
