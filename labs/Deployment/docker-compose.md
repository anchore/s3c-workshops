# Docker Compose

## Requirements
- Docker v1.12 or higher
    - Tested to work on Windows WSL 2
- Docker Compose that supports at least v2 of the docker-compose configuration format.

## Setup

Login to DockerHub with access credentials for the Anchore Enterprise images.
```bash
docker login --username <your-docker-username> # followed by <your-docker-password>
```

Run docker compose and spin up Anchore Enterprise
```bash
docker compose -f anchore-compose.yaml up -d
```

Access the Anchore Enterprise Web UI by visiting http://localhost:3000/ and use the following credentials to login:
- username: `admin`
- password: `anchore12345`