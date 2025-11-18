# Lokale Entwicklung auf Windows - Schritt für Schritt

## Das Problem mit Docker Desktop auf Windows

Docker Desktop auf Windows/WSL2 hat oft Probleme beim Bauen von großen Python-Images (PyTorch, Transformers, etc.). Der `SIGBUS` Fehler zeigt, dass Docker nicht genug Ressourcen hat.

## Bessere Lösung: Hybrid-Ansatz

**Infrastructure in Docker + App lokal laufen lassen**

✅ **Vorteile:**
- Kein Build von großen Docker Images nötig
- Schnellerer Start
- Einfacheres Debugging
- Hot-Reload für API und Frontend
- Weniger RAM-Verbrauch

## Setup - Einmalig durchführen

### Schritt 1: Voraussetzungen installieren

1. **Python 3.11** installieren:
   - Download: https://www.python.org/downloads/
   - ⚠️ WICHTIG: "Add Python to PATH" anhaken!
   - Version prüfen: `python --version`

2. **Node.js 18+** installieren:
   - Download: https://nodejs.org/
   - LTS Version empfohlen
   - Version prüfen: `node --version`

3. **Git** (bereits installiert ✓)

4. **Docker Desktop** (bereits installiert ✓)
   - **Settings → Resources → Advanced:**
     - Memory: 8 GB
     - CPUs: 4
     - Swap: 2 GB

### Schritt 2: Repository Setup

```bash
# In Git Bash oder PowerShell
cd C:\Users\IhrUsername\
git clone https://github.com/MarcusGraetsch/EchoGraph2.git
cd EchoGraph2
```

### Schritt 3: Environment Konfiguration

```bash
# .env generieren
./scripts/setup-env.sh localhost
```

### Schritt 4: Infrastructure Services starten (nur Docker)

```bash
# NUR die Infrastructure Services (PostgreSQL, Redis, Keycloak, etc.)
docker compose -f docker-compose.dev.yml up -d

# Status prüfen (alle sollten "healthy" sein)
docker compose -f docker-compose.dev.yml ps
```

**Warten Sie bis alle Services "healthy" sind (ca. 2-3 Minuten)**

### Schritt 5: Keycloak initialisieren

```bash
# Warten bis Keycloak bereit ist
curl http://localhost:8080

# Realm importieren
./keycloak/init-keycloak.sh
```

### Schritt 6: Backend (API) lokal starten

**Terminal 1 - API:**

```bash
# Python Virtual Environment erstellen
cd C:\Users\IhrUsername\EchoGraph2
python -m venv venv

# Virtual Environment aktivieren
# Für PowerShell:
.\venv\Scripts\Activate.ps1

# Für Git Bash:
source venv/Scripts/activate

# Dependencies installieren (dauert 5-10 Minuten beim ersten Mal)
pip install -r api/requirements.txt
pip install -r ingestion/requirements.txt
pip install -r processing/requirements.txt

# API starten mit Auto-Reload
cd api
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

**API läuft jetzt auf:** http://localhost:8000

### Schritt 7: Frontend lokal starten

**Terminal 2 - Frontend:**

```bash
# In neuem Terminal
cd C:\Users\IhrUsername\EchoGraph2\frontend

# Dependencies installieren
npm install

# Development Server starten
npm run dev
```

**Frontend läuft jetzt auf:** http://localhost:3000

## Täglicher Workflow

Nach dem Setup müssen Sie nur noch:

```bash
# Terminal 1: Infrastructure starten
docker compose -f docker-compose.dev.yml up -d

# Terminal 2: API starten
cd api
source ../venv/Scripts/activate  # oder .\venv\Scripts\Activate.ps1 in PowerShell
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 3: Frontend starten
cd frontend
npm run dev
```

**Entwickeln:**
1. Code ändern in VS Code
2. Speichern → Auto-Reload sieht Änderung sofort
3. Browser aktualisieren
4. Testen

**Stoppen:**
- `Ctrl+C` in den Terminals (API & Frontend)
- `docker compose -f docker-compose.dev.yml down` (Infrastructure)

## Troubleshooting

### "Python not found"

```powershell
# Python Pfad prüfen
python --version

# Wenn nicht gefunden, neu installieren und "Add to PATH" anhaken
```

### "pip install" schlägt fehl

```bash
# Upgrade pip
python -m pip install --upgrade pip

# Mit mehr Details nochmal versuchen
pip install -r api/requirements.txt --verbose
```

### "Module not found" beim API-Start

```bash
# PYTHONPATH setzen
# PowerShell:
$env:PYTHONPATH = "C:\Users\IhrUsername\EchoGraph2"

# Git Bash:
export PYTHONPATH=/c/Users/IhrUsername/EchoGraph2
```

### "Cannot connect to database"

```bash
# Prüfen ob PostgreSQL läuft
docker compose -f docker-compose.dev.yml ps postgres

# Logs prüfen
docker compose -f docker-compose.dev.yml logs postgres

# Neu starten
docker compose -f docker-compose.dev.yml restart postgres
```

### Docker Services starten nicht

```bash
# Alte Container entfernen
docker compose -f docker-compose.dev.yml down -v

# Neu starten
docker compose -f docker-compose.dev.yml up -d

# Logs prüfen
docker compose -f docker-compose.dev.yml logs -f
```

### Port bereits belegt

```powershell
# Prüfen was Port 8000 nutzt
netstat -ano | findstr :8000

# Prozess beenden (PID von oben)
taskkill /PID <PID> /F
```

## Vorteile dieser Methode

✅ **Kein SIGBUS Error** - Kein Docker Build von Python nötig
✅ **Schneller Start** - Infrastructure in 2-3 Minuten bereit
✅ **Hot Reload** - Code-Änderungen sofort sichtbar
✅ **Einfaches Debugging** - Direkt in VS Code debuggen
✅ **Weniger RAM** - Nur Infrastructure in Docker

## VS Code Setup (Optional aber empfohlen)

1. **Extensions installieren:**
   - Python
   - Pylance
   - Docker
   - ESLint
   - Prettier

2. **Launch Configuration** (`.vscode/launch.json`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": [
        "api.main:app",
        "--reload",
        "--host",
        "0.0.0.0",
        "--port",
        "8000"
      ],
      "jinja": true,
      "justMyCode": false,
      "env": {
        "PYTHONPATH": "${workspaceFolder}"
      }
    }
  ]
}
```

Jetzt können Sie F5 drücken um die API im Debug-Mode zu starten!

## Nächste Schritte

Nach erfolgreicher lokaler Entwicklung:

1. ✅ Code ändern und lokal testen
2. ✅ Git commit & push
3. ⏭️ CI/CD Pipeline einrichten (automatisches Deployment)
4. ⏭️ Production-Deployment auf VM

## Hilfe

Bei Problemen:
1. Logs prüfen: `docker compose -f docker-compose.dev.yml logs [service]`
2. Services neu starten: `docker compose -f docker-compose.dev.yml restart`
3. Kompletter Reset: `docker compose -f docker-compose.dev.yml down -v && docker compose -f docker-compose.dev.yml up -d`
