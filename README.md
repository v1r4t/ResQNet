# ResQNet — Dynamic Emergency Response Database

A DBMS course project demonstrating database concepts through a dynamic city-wide emergency transportation network. The system models intersections, road segments, emergency vehicles, incidents, traffic conditions, and routes as interconnected database entities, with the database as the single source of truth.

## Features

- **Real-time incident reporting** — Submit unstructured text reports, LLM extracts structured data, database updates road conditions transactionally
- **Dynamic routing** — Custom Dijkstra/A* algorithm reads live network state from PostgreSQL and writes calculated routes back
- **Historical preservation** — Triggers automatically log all traffic state changes; routes record which network version they were calculated against
- **Spatial queries** — PostGIS-powered nearest vehicle, incident proximity, and geographic analysis
- **Analytics dashboard** — Congestion hotspots, incident frequency, route performance, and EXPLAIN ANALYZE viewer
- **Full-stack deployment** — Docker Compose orchestrates PostGIS, FastAPI backend, and React frontend

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 16 + PostGIS 3.4 |
| Backend | Python 3.11 + FastAPI + psycopg3 + Pydantic |
| Frontend | React 18 + Vite + Tailwind CSS + MapLibre GL JS + Recharts |
| Routing | Custom Dijkstra/A* in Python (reads from DB, writes back) |
| LLM | Gemini/OpenAI pluggable with deterministic mock fallback |
| Deployment | Docker Compose |

## Quick Start

```bash
docker-compose up --build
```

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs

## Project Structure

```
ResQNet/
├── database/                    # SQL migrations
│   ├── 01_schema.sql           # DDL — 15 tables
│   ├── 02_constraints.sql      # 13 indexes (3 GiST + 10 B-tree)
│   ├── 03_triggers.sql         # 4 triggers
│   ├── 04_procedures.sql       # 5 stored procedures/functions
│   ├── 05_views.sql            # 4 views
│   ├── 06_seed_data.sql        # Synthetic city (64 intersections, 224 roads)
│   └── 07_analytics.sql        # EXPLAIN ANALYZE queries
│
├── backend/
│   ├── app/
│   │   ├── main.py             # FastAPI app entry point
│   │   ├── config.py           # Environment config
│   │   ├── database.py         # psycopg3 connection pool
│   │   ├── modules/
│   │   │   ├── incidents/      # Incident ingestion & management
│   │   │   ├── routing/        # Route calculation + worker
│   │   │   ├── vehicles/       # Emergency vehicle management
│   │   │   ├── analytics/      # DB analytics + EXPLAIN ANALYZE
│   │   │   └── network/        # Network state & versioning
│   │   └── llm/                # LLM extraction (mock/Gemini/OpenAI)
│   ├── tests/                  # 48 tests
│   └── Dockerfile
│
├── frontend/
│   ├── src/
│   │   ├── pages/              # 7 pages (Dashboard, Incident Report, etc.)
│   │   ├── components/
│   │   │   ├── map/            # MapLibre GL map with layers
│   │   │   ├── charts/         # Recharts analytics
│   │   │   └── ui/             # Shared UI components
│   │   ├── api/                # API client modules
│   │   └── types/              # TypeScript interfaces
│   └── Dockerfile
│
├── docs/
│   └── superpowers/
│       ├── specs/              # Design spec
│       └── plans/              # Implementation plan
│
└── docker-compose.yml
```

## Database Schema

### Tables (15)
- **Geographic**: `city`, `zone`, `intersection`, `road_segment`
- **Dynamic State**: `traffic_state`, `road_status_history`
- **Incidents**: `incident`, `incident_road` (M:N), `incident_report`
- **Vehicles & Routing**: `emergency_vehicle`, `route_request`, `route`, `route_segment`
- **Versioning**: `network_version`, `route_recalculation_queue`

### Triggers (4)
1. `trg_traffic_state_history` — Logs travel time changes to history
2. `trg_route_invalidation` — Marks routes stale when travel time changes >20%
3. `trg_incident_road_update` — Recalculates road impact from all active incidents
4. `trg_vehicle_location_sync` — Syncs vehicle location geometry

### Stored Procedures (5)
1. `sp_process_incident_report` — Processes unstructured report → structured incident
2. `sp_recalculate_road_impact` — Recalculates travel time from all active incidents
3. `sp_clear_incident` — Clears incident and recalculates affected roads
4. `sp_get_analytics_congestion` — Returns congestion patterns by zone
5. `sp_find_nearest_vehicle` — PostGIS nearest vehicle query

### Views (4)
1. `v_current_network` — Real-time network state with active incidents
2. `v_congestion_hotspots` — Roads with >2x normal travel time
3. `v_incident_frequency` — Incident counts by road, type, and day
4. `v_route_performance` — Estimated vs actual route times

## API Endpoints

### Incidents
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/incidents/report` | Submit unstructured report → LLM extraction → DB |
| POST | `/api/incidents/manual` | Create incident with structured data |
| GET | `/api/incidents` | List incidents (filter by status, severity, zone) |
| GET | `/api/incidents/{id}` | Get incident details |
| GET | `/api/incidents/history` | Get cleared incident history |
| POST | `/api/incidents/{id}/clear` | Clear incident → recalculate roads |
| GET | `/api/incidents/nearby` | Find incidents near a location (PostGIS) |

### Routing
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/routes/request` | Request route → Dijkstra/A* → store |
| POST | `/api/routes/recalculate` | Trigger route recalculation |
| GET | `/api/routes/{id}` | Get route details |
| GET | `/api/routes/request/{request_id}` | Get all routes for a request |
| POST | `/api/routes/{id}/complete` | Record actual travel time |
| GET | `/api/routes/affected/{road_id}` | Find routes affected by a road |

### Vehicles
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/vehicles` | List vehicles |
| GET | `/api/vehicles/status` | Vehicle status summary |
| POST | `/api/vehicles` | Add a vehicle |
| PATCH | `/api/vehicles/{id}/location` | Update vehicle location |
| GET | `/api/vehicles/nearest` | Find nearest vehicle (PostGIS) |

### Analytics
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/analytics/congestion` | Congestion hotspots by zone |
| GET | `/api/analytics/incident-frequency` | Incident frequency |
| GET | `/api/analytics/route-performance` | Route estimation accuracy |
| GET | `/api/analytics/response-times` | Response time analysis |
| GET | `/api/analytics/explain/{query_id}` | EXPLAIN ANALYZE for whitelisted queries |

### Network
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/network/state` | Current network state |
| GET | `/api/network/version` | Current network version |
| GET | `/api/network/history/{road_id}` | Road status history |

## Core Workflow

```
Unstructured Incident Report
        ↓
   LLM / Mock Extraction
        ↓
   Structured Incident
        ↓
PostgreSQL Transaction
        ↓
Trigger / Procedure
        ↓
Update Road & Traffic State
        ↓
Identify Affected Routes
        ↓
   Dijkstra / A*
        ↓
   Store New Route + History
        ↓
  Analytics Dashboard
```

## DBMS Learning Objectives

| Objective | Where Demonstrated |
|-----------|-------------------|
| ER modeling & relational schema | 15-table normalized schema |
| Normalization (3NF) | All tables in 3NF |
| PKs, FKs, composite keys | Throughout schema |
| Referential & domain constraints | CHECK constraints, FKs with ON DELETE |
| Transactions & ACID | Explicit transaction boundaries in all procedures |
| Triggers | 4 triggers for audit, invalidation, cascading updates |
| Stored procedures | 5 procedures for incident processing, analytics |
| Views | 4 views for network state, congestion, performance |
| Indexing & query optimization | 13 indexes, EXPLAIN ANALYZE demonstration |
| Spatial queries (PostGIS) | Nearest vehicle, incident proximity, map rendering |
| Historical/audit preservation | road_status_history, network versioning |
| Complex analytical SQL | Views with aggregation, window functions |
| Concurrency & consistency | Transaction strategy, network versioning |

## Testing

- **48 backend tests** — All passing
- **Frontend build** — Clean (949 modules)
- **Database tests** — Schema, triggers, procedures, views verified

## License

MIT
