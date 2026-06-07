# Keycloak Integration

A self-contained, reusable **identity microservice** built around [Keycloak](https://www.keycloak.org/). Any application — a web SPA, a mobile app, or another backend — can integrate with it quickly over open standards (OIDC / OAuth2 / JWT) to get authentication, JWT-based authorization, and user/profile management, without re-implementing login or touching Keycloak internals.

## Documentation

- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — microservice architecture diagram and integration flow.
- [`BUSINESS_REQUIREMENTS.md`](./BUSINESS_REQUIREMENTS.md) — goal, epics, and user stories (current features + roadmap).

## Components

| Component | Role | Tech |
|---|---|---|
| `keycloak-be` | The identity microservice: REST API, JWT validation (OAuth2 resource server), Keycloak admin client | Spring Boot 3.2.5 · Java 21 |
| `web-app` | Reference React client (SSO via `keycloak-js`), served by nginx | React 18 |
| Keycloak | Externalized identity provider: credentials, tokens, sessions, roles | Keycloak 25.0.0 |
| MongoDB | Application-owned profile store | MongoDB 7.0.11 |

## Run the full stack (Docker Compose)

The quickest way to bring everything up — Keycloak, MongoDB, backend, and frontend:

```bash
export DOCKER_USER=yourdockerhubname   # used for image names
docker compose up -d --build
```

| Service | URL |
|---|---|
| Frontend (web-app) | http://localhost:3000 |
| Backend API (keycloak-be) | http://localhost:8080/profile |
| Keycloak admin console | http://localhost:8180 (admin / admin) |
| MongoDB | localhost:27017 (root / root) |

Tear down (and remove volumes):

```bash
docker compose down -v
```

> **Realm setup:** the stack expects a `hunterkilltree` realm and its clients to exist in Keycloak. For repeatable setup, export your realm and enable auto-import via the commented block in `docker-compose.yml` (`--import-realm`).

## Build & push images to Docker Hub

`deploy.sh` builds the two application images and pushes them to Docker Hub. Keycloak and MongoDB are pulled from public registries and are **not** built or pushed.

```bash
export DOCKER_USER=yourdockerhubname

./deploy.sh            # build both images, log in, push :latest
./deploy.sh build      # build only
./deploy.sh push       # push only (images must already be built)
```

Pushes:

- `${DOCKER_USER}/keycloak-be:latest`
- `${DOCKER_USER}/web-app:latest`

Non-interactive login (CI), using a Docker Hub access token:

```bash
export DOCKER_USER=yourdockerhubname
export DOCKER_PASSWORD=your_access_token
./deploy.sh
```

## Configuration

The backend reads configuration from environment variables (overriding `keycloak-be/src/main/resources/application.yml`). Key variables — see `docker-compose.yml` for the full set:

| Variable | Purpose |
|---|---|
| `SPRING_DATA_MONGODB_URI` | MongoDB connection string |
| `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI` | Where the service fetches Keycloak signing keys |
| `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI` | Expected token issuer |
| `IDP_URL`, `IDP_REALM`, `IDP_CLIENT_ID`, `IDP_CLIENT_SECRET` | Keycloak Admin API / token exchange settings |

> Do not commit real secrets. `IDP_CLIENT_SECRET` and database credentials should come from your environment or a secret manager outside local development.

## Local development (without Docker)

Run the dependencies as standalone containers:

```bash
# Keycloak on port 8180
docker run -d --name keycloak-25.0.0 -p 8180:8080 \
  -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:25.0.0 start-dev

# MongoDB on port 27017
docker run -d --name mongodb-7.0.11 -p 27017:27017 \
  -e MONGODB_ROOT_USER=root -e MONGODB_ROOT_PASSWORD=root \
  bitnami/mongodb:7.0.11
```

Then run each app:

```bash
# Backend
cd keycloak-be && ./mvnw spring-boot:run

# Frontend
cd web-app && npm install && npm start
```
