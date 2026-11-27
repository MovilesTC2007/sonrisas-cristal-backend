## About

This system integrates the deployment and infrastructure supporting the mobile application [SonrisasDeCristal](https://github.com/MovilesTC2007/sonrisas-asistencia-android).

The system reinforces heavily the cibersecurity, observability, CI/CD and deployment.

## Run locally
Copy `.env.example` to `.env` and replace the placeholder values before starting.
The API connects with `API_DB_USER`, not the PostgreSQL administrator account.
Store the password pepper in the file configured by `PASSWORD_PEPPER_FILE`, not
in `.env`. Keep this file private and stable; changing the pepper prevents
existing users from authenticating. Compose mounts the file read-only, but it
remains unencrypted on the host, so restrict access to the file and its backups.
The API image runs as a non-root user. Compose also applies read-only root
filesystems, reduced capabilities, and per-service CPU and memory limits; tune
those limits to the deployment server's capacity.

Development settings are opt-in: the file `compose.dev.yml` is not loaded by
plain `docker compose up`. Include it explicitly to enable the source mount and
FastAPI development server. Nginx creates a self-signed certificate for local
use; browsers will warn that it is not publicly trusted. The development file
also publishes the API and database ports; do not use it for server deployment.
Cloudflared verifies the Nginx certificate. For deployment, set
`CLOUDFLARED_ORIGIN_SERVER_NAME` to a hostname present in the certificate and
use a certificate issued by a trusted CA. Local development explicitly trusts
the public self-signed certificate; it does not disable TLS verification.

```powershell
# Create a private pepper file once; keep its value for future deployments.
New-Item -ItemType Directory -Force secrets | Out-Null
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
[Convert]::ToBase64String($bytes) | Set-Content -NoNewline secrets/password_pepper

# Local development: starts the API, database, and Nginx with a local certificate.
docker compose -f compose.yml -f compose.dev.yml up --build db api nginx-tls
```

## Tech Stack
- Docker
- FastAPI
- Postgres
- Grafana & Prometheus
