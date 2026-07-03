# PINPOINT

AI-powered Public Transport and Tourism Accessibility Platform for Butuan City.

---

## API Keys & Secrets You Need

PINPOINT uses **OpenStreetMap and free public routing services by default** — you do **not** need a Google Maps or Mapbox API key for development or thesis demos. Below is everything you may need, grouped by required vs optional.

### Quick checklist

| Key / secret | Required? | Where to set it | Used for |
|--------------|-----------|-----------------|----------|
| **None for OSM map tiles** | No key | — | Map display (`tile.openstreetmap.org`) |
| **None for OSM search (dev)** | No key | — | Place search (`nominatim.openstreetmap.org`) |
| **None for OSRM routing (dev)** | No key | — | Walk / drive routes (`router.project-osrm.org`) |
| **`API_URL`** | Cloud mode only | `.env.flutter.json` | Flutter → your Render/local backend |
| **`SECRET_KEY`** | Backend (production) | `backend/.env` or Render | Flask session signing |
| **`JWT_SECRET_KEY`** | Backend (production) | `backend/.env` or Render | Login tokens |
| **`DATABASE_URL`** | Backend (production) | `backend/.env` or Render | PostgreSQL on Render |
| **`OPENAI_API_KEY`** | Optional | `backend/.env` or Render | Cloud AI chat (RAG) |
| **`OPENROUTER_KEY`** | Optional | `backend/.env` or Render | Alternative LLM provider |
| **`OFFLINE_FIRST_MODE`** | Optional | `.env.flutter.json` | Skip backend entirely (thesis mode) |

---

### Maps & location (Flutter app)

PINPOINT does **not** use Google Maps or Mapbox. Maps are built with **flutter_map** + **OpenStreetMap**.

#### OpenStreetMap map tiles — **no API key**

| Service | Default URL | API key? |
|---------|-------------|----------|
| Light map tiles | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | **No** |
| Dark map tiles | `https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png` | **No** |

Defined in `lib/app/constants.dart`. Tiles download over the internet and are cached by the map engine while you pan/zoom.

**Important for production/thesis defense:**
- Public OSM tile servers are for **light / non-commercial use**. For heavy traffic or a published app, host your own tiles or use a paid tile provider (MapTiler, Stadia Maps, etc.).
- If you switch to a paid provider later, you would add their API key and replace `osmTileUrl` / `darkTileUrl` in `constants.dart` — **not required today**.

#### Nominatim (place search) — **no API key (dev)**

| Service | Default URL | API key? |
|---------|-------------|----------|
| Forward geocoding (search bar) | `https://nominatim.openstreetmap.org/search` | **No** |

The app sends a `User-Agent: PINPOINT-Butuan/0.1.0` header (see `lib/core/services/geocoding_service.dart`). Nominatim’s [usage policy](https://operations.osmfoundation.org/policies/nominatim/) limits heavy use — fine for thesis demos; for production use your own Nominatim instance or a geocoding API with a key.

#### OSRM (walking & driving routes) — **no API key (dev)**

| Service | Default URL | API key? |
|---------|-------------|----------|
| Walking routes | `https://router.project-osrm.org/route/v1/foot/...` | **No** |
| Taxi / tricycle paths | `https://router.project-osrm.org/route/v1/driving/...` | **No** |

Defined in `lib/core/services/routing_service.dart`. The public OSRM server is a **demo** — use a self-hosted OSRM or a routing API with a key for production scale.

#### Device GPS — **no API key**

Location uses the `geolocator` plugin (device GPS). Reverse geocoding for “current address” uses the platform `geocoding` package (Android/iOS), not a Google API key in this project.

#### Map-related keys you do **not** need (current codebase)

- Google Maps API key — **not used**
- Mapbox access token — **not used**
- HERE / TomTom maps key — **not used**

---

### Flutter app configuration (not third-party API keys)

Copy `.env.flutter.example.json` → `.env.flutter.json`:

```json
{
  "API_URL": "https://pinpoint-api.onrender.com/api",
  "OFFLINE_FIRST_MODE": "false"
}
```

| Variable | Required when | Example |
|----------|---------------|---------|
| `API_URL` | Using cloud or local backend | `https://pinpoint-api.onrender.com/api` |
| `OFFLINE_FIRST_MODE` | Thesis / offline-only mode | `true` = no server needed |

```bash
flutter run --dart-define-from-file=.env.flutter.json
flutter build apk --release --dart-define-from-file=.env.flutter.json
```

**Emulator / device URLs:**

| Target | `API_URL` |
|--------|-----------|
| Android emulator → PC backend | `http://10.0.2.2:5000/api` |
| Physical phone → PC (same Wi‑Fi) | `http://<your-pc-lan-ip>:5000/api` |
| Render cloud | `https://<your-service>.onrender.com/api` |

---

### Backend secrets (Render / `backend/.env`)

Copy `backend/.env.example` → `backend/.env` for local development.

#### Required for production backend

| Variable | How to get it | Notes |
|----------|---------------|-------|
| `SECRET_KEY` | Random string (Render can auto-generate) | Flask app secret |
| `JWT_SECRET_KEY` | Random string, **32+ characters** | Auth token signing |
| `DATABASE_URL` | Render PostgreSQL (auto-linked) or SQLite locally | `postgres://...` normalized automatically |

#### Optional backend

| Variable | When you need it |
|----------|----------------|
| `OPENAI_API_KEY` | Cloud AI chat with OpenAI (`gpt-4o-mini` default) |
| `OPENROUTER_KEY` | Cloud AI via [OpenRouter](https://openrouter.ai/) instead of OpenAI |
| `OPENAI_BASE_URL` | Custom OpenAI-compatible endpoint (default `https://api.openai.com/v1`) |
| `AI_USE_CHROMA` | `true` only if you enable vector RAG + persistent disk on Render |

#### Not API keys (backend tuning)

`FLASK_ENV`, `DEBUG_MODE`, `AUTO_SEED`, `CORS_ORIGINS`, `PORT`, `APP_VERSION`, `CACHE_TTL_SECONDS`, `VECTOR_DB_PATH`, `AI_MODEL` — see `backend/.env.example`.

**Offline-first thesis mode:** you can run the Flutter app with `OFFLINE_FIRST_MODE=true` and skip the backend entirely — then `SECRET_KEY`, `JWT_SECRET_KEY`, and `OPENAI_API_KEY` are not needed for core features.

---

### Render (cloud) — what Render provides vs what you add

`render.yaml` auto-creates:

- `SECRET_KEY` (generated)
- `JWT_SECRET_KEY` (generated)
- `DATABASE_URL` (from `pinpoint-db` PostgreSQL)

**You manually add (optional):**

- `OPENAI_API_KEY` — for server-side RAG AI chat
- `OPENROUTER_KEY` — if using OpenRouter instead of OpenAI

**You do not add on Render for maps** — map tiles, Nominatim, and OSRM are called from the **Flutter app** to public endpoints (no keys in current setup).

---

### Minimum setups

| Goal | API keys / secrets needed |
|------|---------------------------|
| **Thesis demo (offline)** | None — `OFFLINE_FIRST_MODE=true` |
| **Thesis demo (maps + routing online)** | None — OSM / Nominatim / OSRM public endpoints |
| **App + Render backend (auth, sync, tourism API)** | `API_URL` + Render `SECRET_KEY` + `JWT_SECRET_KEY` + `DATABASE_URL` |
| **App + backend + cloud AI** | Above + `OPENAI_API_KEY` or `OPENROUTER_KEY` |
| **Production maps at scale** | Consider paid tile/geocoding/routing providers (not in repo yet) |

---

## Project Structure

```
PINPOINT__MOBILE/
├── lib/                 # Flutter application (Clean Architecture)
├── backend/             # Flask REST API
├── assets/              # Bundled offline data (routes, tourism, fares)
├── test/                # Flutter tests
├── render.yaml          # Render Blueprint (API + PostgreSQL)
├── docker-compose.yml   # Local Docker API
└── .github/workflows/   # CI pipeline
```

## Features (v2.0.0)

- **Offline-first** — Bundled assets + Hive; works without a server (thesis mode)
- **Cloud-ready** — Render via `render.yaml`; `API_URL` at build time
- **Maps & routing** — OpenStreetMap tiles, color-coded jeepney / tricycle / taxi routes, national-highway tricycle rules
- **Tourism** — Attractions, establishments, nearby search
- **AI assistant** — Local keyword retrieval offline; cloud RAG when `OPENAI_API_KEY` is set
- **Personalization** — Favorites, history, sync, biometrics, accessibility, EN / TL / CEB

## Getting Started

### Flutter

```bash
flutter pub get
cp .env.flutter.example.json .env.flutter.json
flutter run --dart-define-from-file=.env.flutter.json
```

**Offline thesis mode (no backend, no API keys):**

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:5000/api --dart-define=OFFLINE_FIRST_MODE=true
```

### Backend (local)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt
copy .env.example .env
python run.py
```

API: `http://localhost:5000/api` · Emulator: `http://10.0.2.2:5000/api`  
**Dev admin:** `admin@pinpoint.local` / `AdminPass1`

### Docker

```bash
docker compose up --build
```

Health check: `GET http://localhost:5000/health`

### PostgreSQL (optional)

```bash
docker compose --profile postgres up --build api-postgres
```

## Deploy to Render

1. Push repo to GitHub.
2. Render Dashboard → **New** → **Blueprint** → connect repo.
3. Note API URL: `https://pinpoint-api.onrender.com` (or your service name).
4. Set `.env.flutter.json` → `"API_URL": "https://<your-service>.onrender.com/api"`.
5. Optionally add `OPENAI_API_KEY` in Render for cloud AI.

See `render.yaml`, `backend/.env.example`, and `.env.flutter.example.json` for full variable lists.

## Tests

```bash
flutter analyze && flutter test
cd backend && pytest
```

## Environment file reference

| File | Purpose |
|------|---------|
| `.env.example` | Flutter `dart-define` comments |
| `.env.flutter.example.json` | Copy to `.env.flutter.json` for builds |
| `backend/.env.example` | Backend / Render variables |
| `render.yaml` | Render Blueprint |

## Version

`v2.0.0`
