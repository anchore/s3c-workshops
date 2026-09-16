# Docker Compose

## Requirements
- Docker Engine v29.0 or higher
    - Tested to work on Windows WSL 2
- Docker Compose v5.0 or higher
    - Ships with Docker Desktop, or as the `docker-compose-plugin` package on Linux

## Setup

Place your *license.yaml* file into the directory with docker-compose.yaml

Login to DockerHub with access credentials for the Anchore Enterprise images.
```bash
docker login --username <your-docker-username>

Run docker compose and spin up Anchore Enterprise

```bash
docker compose up -d
```

Access the Anchore Enterprise Web UI by visiting http://localhost:3000/ and use the following credentials to login:
- username: `admin`
- password: `anchore12345` (or your password set in *.env*)

## Next Step

Now that you have Anchore Enterprise operational, [proceed to the next step](../README.md) of the lab.
