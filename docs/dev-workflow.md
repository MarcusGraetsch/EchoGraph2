# Verbesserter Entwicklungs-Workflow für EchoGraph

## Problem mit dem aktuellen Workflow

**Aktuell:**
```
VM → git clone → deploy.sh → Fehler → VM löschen → wiederholen
```

**Probleme:**
- Kein Debugging möglich
- Langsamer Iterationszyklus (jedes Mal 5-10 Minuten Setup)
- Keine Fehleranalyse möglich
- Keine lokale Entwicklung

## Empfohlener neuer Workflow

### 1. Lokale Entwicklung (EMPFOHLEN)

**Vorteile:**
- ✅ Schnelle Iteration (Sekunden statt Minuten)
- ✅ Vollständiges Debugging mit IDE
- ✅ Logs sofort verfügbar
- ✅ Hot-Reload für Frontend und Backend
- ✅ Gleiche Docker-Umgebung wie Produktion

**Setup:**

```bash
# Auf lokalem Rechner (Windows/Mac/Linux mit Docker Desktop)
git clone https://github.com/MarcusGraetsch/EchoGraph2.git
cd EchoGraph2

# Lokale .env generieren
./scripts/setup-env.sh localhost

# Services starten
docker-compose up -d

# Frontend im Development-Modus starten (Hot Reload!)
cd frontend
npm install
npm run dev

# API im Development-Modus starten (mit Auto-Reload)
cd api
pip install -r requirements.txt
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

**Entwicklungszyklus:**
1. Code ändern im Editor
2. Speichern → Auto-Reload sieht Änderung sofort
3. Testen im Browser
4. Bei Erfolg: commit & push
5. CI/CD deployed automatisch

**Kosten:** Keine zusätzlichen Kosten (läuft auf lokalem Rechner)

### 2. Development/Staging/Production Environments

**Struktur:**
```
┌─────────────────┐
│ Local Dev       │ ← Entwickler arbeiten hier
│ (Docker Desktop)│
└────────┬────────┘
         │ git push
         ▼
┌─────────────────┐
│ GitHub Actions  │ ← Automatische Tests & Builds
│ (CI/CD Pipeline)│
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│Staging │ │  Prod  │ ← Automatisches Deployment
│  VM    │ │   VM   │
└────────┘ └────────┘
```

### 3. CI/CD Pipeline mit GitHub Actions

**Was automatisch passiert:**

1. **Bei jedem Push:**
   - Code-Linting
   - Unit Tests
   - Integration Tests
   - Docker Image Build
   - Push zu Container Registry

2. **Bei merge zu `main`:**
   - Deployment zu Staging VM
   - Smoke Tests
   - Bei Erfolg: Auto-Deploy zu Production (optional)

**Vorteile:**
- ✅ Keine manuellen Deployments mehr
- ✅ Konsistente Builds
- ✅ Automatische Tests
- ✅ Rollback bei Fehlern
- ✅ Deployment-Historie

**Kosten:** GitHub Actions ist kostenlos für Public Repos (2000 Minuten/Monat für Private)

### 4. Kubernetes (NICHT sofort empfohlen!)

**Wann K8s Sinn macht:**
- ❌ NICHT für Projekte mit <1000 Nutzern
- ❌ NICHT wenn Team <5 Entwickler
- ❌ NICHT wenn kein DevOps-Experte im Team
- ✅ JA wenn Multi-Tenancy nötig
- ✅ JA wenn Auto-Scaling kritisch
- ✅ JA wenn >10 Services orchestriert werden müssen

**Aktuell:** Docker Compose reicht völlig aus!

## Konkrete Umsetzung

### Phase 1: Sofort (1 Tag)

**Ziel:** Aktuelle Probleme fixen ohne VM wegzuwerfen

```bash
# Auf der VM:
# 1. Logs sammeln
docker-compose logs keycloak > keycloak-logs.txt
docker-compose logs api > api-logs.txt
docker-compose logs frontend > frontend-logs.txt

# 2. Service Status prüfen
docker-compose ps

# 3. Netzwerk prüfen
docker network inspect echograph2_echograph-network

# 4. Keycloak-Realm prüfen
curl -s http://localhost:8080/realms/echograph | jq .

# 5. MinIO Status prüfen
docker-compose logs minio
```

**Diese Logs helfen uns die echten Probleme zu identifizieren!**

### Phase 2: Lokale Entwicklung einrichten (2-3 Tage)

**Tag 1: Setup**
```bash
# Auf lokalem Rechner
git clone https://github.com/MarcusGraetsch/EchoGraph2.git
cd EchoGraph2

# Docker Desktop installieren (falls nicht vorhanden)
# Windows: https://www.docker.com/products/docker-desktop/
# Mac: https://www.docker.com/products/docker-desktop/
# Linux: sudo apt install docker.io docker-compose

# Services starten
./deploy.sh

# Frontend und Backend im Dev-Mode
cd frontend && npm run dev &
cd ../api && uvicorn api.main:app --reload &
```

**Tag 2-3: Workflow testen**
- Feature lokal entwickeln
- Testen
- Commit & Push
- Auf VM deployen (manuell erstmal)

### Phase 3: CI/CD Pipeline (1 Woche)

**Dateien die wir erstellen:**

1. `.github/workflows/test.yml` - Tests bei jedem Push
2. `.github/workflows/build.yml` - Docker Images bauen
3. `.github/workflows/deploy-staging.yml` - Auto-Deploy zu Staging
4. `.github/workflows/deploy-prod.yml` - Manual Deploy zu Production
5. `docker-compose.prod.yml` - Production-optimierte Config

**Features:**
- ✅ Automatische Tests
- ✅ Docker Image Registry (GitHub Container Registry)
- ✅ Automated Deployment
- ✅ Health Checks
- ✅ Rollback bei Fehlern

## Kosten-Vergleich

| Ansatz | Setup | Laufende Kosten | Entwickler-Zeit |
|--------|-------|-----------------|-----------------|
| **Aktuell (VM wegwerfen)** | 0€ | VM: ~10€/Monat | 🔴 Sehr hoch (Stunden/Tag) |
| **Lokal + CI/CD** | 0€ | VM: ~10€/Monat | 🟢 Sehr niedrig (Minuten/Tag) |
| **Kubernetes** | 500€ Setup | ~100€/Monat | 🟡 Mittel (braucht DevOps) |

## Troubleshooting Best Practices

**Statt VM wegwerfen:**

1. **Logs prüfen:**
   ```bash
   docker-compose logs [service-name] --tail=100 -f
   ```

2. **Service neu starten:**
   ```bash
   docker-compose restart [service-name]
   ```

3. **Einzelnen Service rebuilden:**
   ```bash
   docker-compose build --no-cache [service-name]
   docker-compose up -d [service-name]
   ```

4. **Alle Services neu bauen (behält aber Daten!):**
   ```bash
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```

5. **Kompletter Reset (löscht Daten!):**
   ```bash
   docker-compose down -v  # -v löscht Volumes
   docker-compose up -d
   ./keycloak/init-keycloak.sh
   ```

## Entscheidungshilfe

**Starte mit lokaler Entwicklung wenn:**
- ✅ Du willst sofort produktiver sein
- ✅ Du willst schnell iterieren
- ✅ Du willst echtes Debugging

**Gehe zu CI/CD wenn:**
- ✅ Du deployest mehrmals pro Woche
- ✅ Du willst automatische Tests
- ✅ Du hast mehr als 1 Entwickler

**Gehe zu Kubernetes wenn:**
- ✅ Du brauchst >99.9% Uptime
- ✅ Du hast >10 Microservices
- ✅ Du brauchst Auto-Scaling
- ✅ Du hast DevOps-Expertise im Team

**Für EchoGraph aktuell: Lokale Entwicklung + CI/CD ist optimal!**

## Nächste Schritte

1. **Sofort:** Aktuelle Fehler analysieren (nicht VM wegwerfen!)
2. **Diese Woche:** Lokale Entwicklung einrichten
3. **Nächste Woche:** GitHub Actions CI/CD Pipeline
4. **Später:** Production-Optimierungen (HTTPS, Monitoring, Backups)

## Fragen?

- Brauchst Du Hilfe beim Setup der lokalen Umgebung?
- Soll ich die GitHub Actions Workflows für Dich erstellen?
- Möchtest Du, dass ich die aktuellen Fehler analysiere?
