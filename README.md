# Service Kafka

A local **3-node Apache Kafka cluster in KRaft mode** (no ZooKeeper) with **Kafka UI**, run with Docker Compose.
It is a ready-to-use playground for developing and testing services that produce to and consume from Kafka.

## Features

- **3 brokers, KRaft mode.** Each node is both a broker and a controller, so the cluster keeps working if one node goes down.
- **No ZooKeeper.** Metadata is managed by the built-in Raft quorum (`kafka1`, `kafka2`, `kafka3`).
- **Kafka UI** at <http://localhost:8080> to browse topics, messages, consumer groups and brokers.
- **Persistent data.** Each broker stores its data in `./kafka-data/<node>`, so topics and messages survive restarts.
- **Health checks.** Kafka UI starts only after all three brokers report healthy.
- **Explicit topics.** Auto-creation of topics is disabled (`auto.create.topics.enable=false`), so every topic is created on purpose.

## Stack

| Component | Image | Version |
|-----------|-------|---------|
| Apache Kafka (KRaft) | `bitnami/kafka` | 3.6.1 |
| Kafka UI | `provectuslabs/kafka-ui` | latest |
| Orchestration | Docker Compose | v2 |

## Architecture

```
                 ┌──────────────── kafka-network (bridge) ────────────────┐
                 │                                                        │
 localhost:19092 ─┼─► kafka1 ◄──┐                                          │
 localhost:19093 ─┼─► kafka2 ◄──┼── KRaft controller quorum (port 9093)    │
 localhost:19094 ─┼─► kafka3 ◄──┘                                          │
                 │      ▲                                                 │
                 │      │ kafka1:9092, kafka2:9092, kafka3:9092           │
 localhost:8080  ─┼─► kafka-ui                                             │
                 └────────────────────────────────────────────────────────┘
```

| Service | Container port | Host port | Purpose |
|---------|----------------|-----------|---------|
| `kafka1` | 9092 (client), 9093 (controller) | 19092 | Broker + controller, node 1 |
| `kafka2` | 9092 (client), 9093 (controller) | 19093 | Broker + controller, node 2 |
| `kafka3` | 9092 (client), 9093 (controller) | 19094 | Broker + controller, node 3 |
| `kafka-ui` | 8080 | 8080 | Web UI for the cluster |

## Getting started

### Prerequisites

- Docker with the Compose plugin (`docker compose`)
- `make` (optional, for the shortcuts below)
- Linux, macOS, or Windows with WSL2

### Run

```bash
git clone https://github.com/FeeRro/Service_Kafka.git
cd Service_Kafka

make run-compose          # docker compose up -d
```

The Bitnami image runs as a non-root user, so the data directories must be writable.
If the brokers fail to start with permission errors on the first run, fix the permissions and start again:

```bash
make get-permission       # sudo chmod 777 ./kafka-data/*
make run-compose
```

Check that everything is up:

```bash
docker compose ps
```

Then open Kafka UI at <http://localhost:8080>.

### Stop

```bash
make down-compose         # docker compose down
```

Data in `./kafka-data` is kept. To start from a clean cluster, remove that directory after stopping.

## Usage

### Create a topic

Topics are not created automatically, so create one before producing:

```bash
docker exec -it kafka1 kafka-topics.sh \
  --bootstrap-server kafka1:9092 \
  --create --topic orders \
  --partitions 3 --replication-factor 3
```

You can also create topics from Kafka UI.

### Produce and consume from the CLI

```bash
# producer
docker exec -it kafka1 kafka-console-producer.sh \
  --bootstrap-server kafka1:9092 --topic orders

# consumer (in another terminal)
docker exec -it kafka2 kafka-console-consumer.sh \
  --bootstrap-server kafka2:9092 --topic orders --from-beginning
```

### Connect an application

Brokers advertise their internal hostnames (`kafka1:9092`, `kafka2:9092`, `kafka3:9092`).
The simplest way to connect a service is to run it in the same Compose network and use:

```
kafka1:9092,kafka2:9092,kafka3:9092
```

Ports 19092–19094 are published on the host, but a client running on the host will be redirected to the
advertised `kafkaN:9092` addresses. To connect from the host, either map `kafka1`, `kafka2`, `kafka3`
to `127.0.0.1` in your hosts file and use the matching ports, or add a separate external listener to the brokers.

## Make targets

| Target | Command | Description |
|--------|---------|-------------|
| `run-compose` | `docker compose up -d` | Start the cluster and Kafka UI in the background |
| `down-compose` | `docker compose down` | Stop and remove the containers (data is kept) |
| `get-permission` | `sudo chmod 777 ./kafka-data/*` | Make broker data directories writable |

## Project structure

```
.
├── docker-compose.yaml   # 3 KRaft brokers + Kafka UI
├── makefile              # shortcuts for starting and stopping the stack
├── .gitignore            # excludes kafka-data/
└── README.md
```

## Notes

- This setup is meant for local development: it uses `PLAINTEXT` listeners with no authentication or TLS.
- `KAFKA_KRAFT_CLUSTER_ID` is fixed in `docker-compose.yaml`. All nodes must share the same ID; if you change it, delete `./kafka-data` first.
