# EchoGraph Development Roadmap

## 🎉 Recent Updates (Stand: 2025-11-19)

### ✅ Completed Quick Wins
- **Quick Fix #1**: Dashboard Statistics API Integration (COMPLETED)
  - Added `getStatistics()` method to `lib/api.ts`
  - Dashboard now fetches real statistics from `/api/documents/statistics/dashboard`
  - Stats auto-refresh after successful upload
  - Loading states added for better UX

- **Quick Fix #2**: Search API Integration (COMPLETED)
  - Removed hardcoded alert message
  - Search now calls real API endpoint `/api/search`
  - Results logged to console (UI pending Phase 2)
  - Error handling implemented

## Current Status (Stand: 2025-11-18)

### ✅ Was funktioniert

**Infrastructure:**
- PostgreSQL mit pgvector
- Redis für Celery
- MinIO Object Storage
- Qdrant Vector Database (Container läuft)
- Keycloak Authentication
- n8n Workflow Engine
- Docker Compose Setup

**Backend:**
- Keycloak Integration & Authentication
- File Upload zu MinIO
- Document CRUD API Endpoints
- Relationship CRUD API Endpoints
- Database Models (Document, Chunk, Relationship)
- Text Extraction (PDF, DOCX mit OCR Support)
- Text Chunking Algorithmen
- Embedding Generation (sentence-transformers)
- WebSocket Infrastructure

**Frontend:**
- Login/Logout mit Keycloak
- Drag & Drop File Upload
- Upload Progress Tracking
- Basic Dashboard Layout

### ⚠️ Was teilweise funktioniert

**Problem #1: File Upload aktualisiert UI nicht**
- Upload funktioniert → Datei landet in MinIO + DB
- ABER: Keine Verarbeitung danach
- Status bleibt bei "PROCESSING" stehen
- Dashboard Stats zeigen immer 0

**Ursache:**
- Celery Task für Document Processing ist nicht implementiert (nur Placeholder)
- Frontend ruft Dashboard Statistics API nicht ab (hardcoded 0)
- Keine Qdrant Integration (Container läuft, aber kein Python Client Code)

**Problem #2: Search zeigt nur Alert**
- Search API Endpoint existiert
- ABER: Frontend zeigt nur Alert-Message
- Backend nutzt einfaches SQL LIKE statt Semantic Search

### ❌ Was fehlt komplett

**Backend:**
- Qdrant Vector Database Integration
- Implementierung der Celery Tasks (process_document, extract_relationships)
- Semantic Search mit Embeddings
- AI-basierte Relationship Detection
- Automated Compliance Checking

**Frontend:**
- Document List View (Library)
- Document Detail Viewer
- Search Results Display
- Relationship Visualization
- Validation Queue UI
- Real-time Updates via WebSocket
- Dashboard Charts mit echten Daten

---

## Development Roadmap - Phase Plan

### 🚀 Phase 1: Core Document Processing (2-3 Wochen)

**Ziel:** Dokumente vollständig verarbeiten - von Upload bis Embeddings in Qdrant

#### 1.1 Qdrant Integration (2-3 Tage)
**Priorität:** CRITICAL ⚠️

**Aufgaben:**
- [ ] Qdrant Python Client einrichten
- [ ] Neues Modul: `processing/vector_store.py`
  - Collection Management (create, delete)
  - Vector Upload (batch insert)
  - Semantic Search (similarity search)
  - Hybrid Search (vector + metadata filters)
- [ ] Qdrant Collections Schema definieren:
  - `documents` collection (document-level embeddings)
  - `chunks` collection (chunk-level embeddings mit metadata)
- [ ] Unit Tests für Qdrant Integration

**Dateien:**
```
processing/vector_store.py         (neu)
tests/test_vector_store.py         (neu)
```

**Akzeptanzkriterien:**
- ✅ Kann Embeddings in Qdrant speichern
- ✅ Kann Semantic Search durchführen
- ✅ Kann ähnliche Dokumente finden

---

#### 1.2 Document Processing Pipeline (3-5 Tage)
**Priorität:** CRITICAL ⚠️

**Aufgaben:**
- [ ] Celery Task `process_document()` implementieren
  - Text Extraction aufrufen (bereits implementiert)
  - Text in Chunks aufteilen (bereits implementiert)
  - Embeddings generieren (bereits implementiert)
  - Embeddings in Qdrant speichern (neu)
  - Document Status aktualisieren (PROCESSING → READY oder ERROR)
- [ ] Error Handling & Retry Logic
- [ ] Progress Updates via WebSocket
- [ ] Unit & Integration Tests

**Dateien:**
```
api/tasks.py                       (update)
api/routers/documents.py           (uncomment line 138)
tests/test_tasks.py                (neu)
```

**Workflow:**
```
Upload → MinIO → DB Record → Celery Task
                                    ↓
                    1. Extract Text (PDF/DOCX)
                    2. Chunk Text
                    3. Generate Embeddings
                    4. Store in Qdrant
                    5. Update Status → READY
```

**Akzeptanzkriterien:**
- ✅ Upload löst automatisch Verarbeitung aus
- ✅ Status ändert sich zu READY nach erfolgreicher Verarbeitung
- ✅ Bei Fehler: Status ERROR + Error Message in DB
- ✅ Embeddings in Qdrant gespeichert

---

#### 1.3 Dashboard Statistics API Integration (1 Tag)
**Priorität:** HIGH

**Aufgaben:**
- [ ] Frontend: `GET /api/documents/statistics/dashboard` aufrufen
- [ ] Dashboard State Management (React Query oder SWR)
- [ ] Loading States & Error Handling
- [ ] Auto-Refresh alle 30 Sekunden

**Dateien:**
```
frontend/src/app/dashboard/page.tsx    (update)
frontend/src/lib/api.ts                (update)
```

**Akzeptanzkriterien:**
- ✅ Dashboard zeigt echte Zahlen statt 0
- ✅ Total Documents aktualisiert sich nach Upload
- ✅ Norms vs Guidelines Breakdown korrekt

---

#### 1.4 Document List View (2-3 Tage)
**Priorität:** HIGH

**Aufgaben:**
- [ ] Neue Seite: `frontend/src/app/documents/page.tsx`
- [ ] DocumentTable Component
  - Spalten: Name, Type, Status, Upload Date, Actions
  - Pagination
  - Filtering (by type, status)
  - Sorting
- [ ] Integration mit `GET /api/documents`
- [ ] Delete Funktion
- [ ] View/Download Funktion

**Dateien:**
```
frontend/src/app/documents/page.tsx           (neu)
frontend/src/components/DocumentTable.tsx     (neu)
frontend/src/components/DocumentRow.tsx       (neu)
frontend/src/components/DocumentFilter.tsx    (neu)
```

**Akzeptanzkriterien:**
- ✅ Alle hochgeladenen Dokumente sichtbar
- ✅ Filter nach Type (Norm/Guideline) funktioniert
- ✅ Pagination bei >20 Dokumenten
- ✅ Delete löscht Dokument + MinIO File

---

### Phase 1 Milestone: **Dokumente vollständig verarbeitet & sichtbar**

**Demo:**
1. Dokument hochladen
2. Status wechselt automatisch zu READY
3. Dashboard zeigt 1 Document
4. Document List zeigt hochgeladenes Dokument
5. Qdrant enthält Embeddings

---

### 🔍 Phase 2: Semantic Search (1-2 Wochen)

**Ziel:** Echte Semantic Search statt SQL LIKE

#### 2.1 Backend: Semantic Search Implementation (3-4 Tage)
**Priorität:** HIGH

**Aufgaben:**
- [ ] `api/routers/search.py` umbauen:
  - Query Text → Embedding generieren
  - Qdrant Semantic Search
  - Hybrid Search (Semantic + Metadata Filter)
  - Ranking & Scoring
- [ ] Advanced Search Features:
  - Filter by Document Type
  - Filter by Date Range
  - Filter by Status
  - Threshold für Similarity Score
- [ ] Performance Optimization (Caching)

**Dateien:**
```
api/routers/search.py              (update - remove TODO line 31)
api/services/search_service.py     (neu)
```

**Akzeptanzkriterien:**
- ✅ Semantic Search findet ähnliche Dokumente auch ohne exakte Keywords
- ✅ Hybrid Search kombiniert Semantic + Metadata
- ✅ Results sortiert nach Relevanz-Score

---

#### 2.2 Frontend: Search Results UI (2-3 Tage)
**Priorität:** HIGH

**Aufgaben:**
- [ ] Search Results Page: `frontend/src/app/search/page.tsx`
- [ ] SearchResults Component
  - Result Cards mit Highlight
  - Relevance Score anzeigen
  - Snippet/Preview
  - Link zu Document Detail
- [ ] Advanced Search Filters UI
- [ ] Search History (optional)

**Dateien:**
```
frontend/src/app/search/page.tsx        (neu)
frontend/src/components/SearchResults.tsx  (neu)
frontend/src/components/SearchFilters.tsx  (neu)
frontend/src/components/ResultCard.tsx     (neu)
```

**Akzeptanzkriterien:**
- ✅ Search zeigt echte Results statt Alert
- ✅ Relevance Score sichtbar
- ✅ Click auf Result → Document Detail Page
- ✅ Filters funktionieren

---

### Phase 2 Milestone: **Semantic Search funktional**

**Demo:**
1. Suche nach "Datenschutz"
2. Findet Dokumente mit "GDPR", "Privacy", "personenbezogene Daten"
3. Results sortiert nach Relevanz
4. Click auf Result zeigt Document

---

### 🔗 Phase 3: Relationship Detection (2-3 Wochen)

**Ziel:** Automatische Erkennung von Beziehungen zwischen Dokumenten

#### 3.1 Relationship Extraction Celery Task (4-5 Tage)
**Priorität:** MEDIUM

**Aufgaben:**
- [ ] `api/tasks.py` - `extract_relationships()` implementieren:
  - Qdrant: Finde ähnliche Chunks (Threshold: >0.8)
  - Gruppiere nach Source Document
  - Klassifiziere Relationship Type (siehe unten)
  - Speichere in `document_relationships` table
  - Status: `pending_review` (für Human-in-the-Loop)
- [ ] Relationship Type Classification:
  - COMPLIANCE: Guideline implementiert Norm-Anforderung
  - CONFLICT: Widerspruch zwischen Dokumenten
  - REFERENCE: Explicit reference/citation
  - SIMILAR: Ähnlicher Inhalt
  - SUPERSEDES: Neuere Version ersetzt alte
- [ ] Optional: LLM Integration (GPT-4/Claude) für genauere Klassifikation

**Dateien:**
```
api/tasks.py                          (update - implement line 91)
api/services/relationship_service.py  (neu)
```

**Akzeptanzkriterien:**
- ✅ Automatisch erkannte Relationships in DB
- ✅ Relationship Types korrekt klassifiziert
- ✅ Confidence Score für jede Relationship

---

#### 3.2 Relationship Visualization (3-4 Tage)
**Priorität:** MEDIUM

**Aufgaben:**
- [ ] Document Detail Page mit Relationships
- [ ] RelationshipCard Component:
  - Type Icon (Compliance, Conflict, etc.)
  - Source & Target Document
  - Confidence Score
  - Snippet/Explanation
  - Validate/Reject Buttons (für Review)
- [ ] Network Graph (optional):
  - React Flow oder D3.js
  - Nodes = Documents
  - Edges = Relationships

**Dateien:**
```
frontend/src/app/documents/[id]/page.tsx      (neu)
frontend/src/components/RelationshipCard.tsx  (neu)
frontend/src/components/RelationshipGraph.tsx (neu - optional)
```

**Akzeptanzkriterien:**
- ✅ Document Detail zeigt alle Relationships
- ✅ Relationship Type visuell unterscheidbar
- ✅ Click auf Related Document navigiert dorthin

---

#### 3.3 Validation Queue (2-3 Tage)
**Priorität:** MEDIUM

**Aufgaben:**
- [ ] Validation Queue Page: `frontend/src/app/validation/page.tsx`
- [ ] Zeigt alle Relationships mit Status `pending_review`
- [ ] Review UI:
  - Side-by-side Document Viewer
  - Approve/Reject Buttons
  - Add Comment
  - Bulk Actions
- [ ] Integration mit `POST /api/relationships/{id}/validate`

**Dateien:**
```
frontend/src/app/validation/page.tsx        (neu)
frontend/src/components/ValidationQueue.tsx (neu)
frontend/src/components/ReviewPanel.tsx     (neu)
```

**Akzeptanzkriterien:**
- ✅ Alle pending Relationships sichtbar
- ✅ Approve → Status `validated`
- ✅ Reject → Status `rejected` + Reason
- ✅ Approved Relationships erscheinen in Document Details

---

### Phase 3 Milestone: **Automatische Relationship Detection + Review**

**Demo:**
1. Upload Norm-Dokument + Company Guideline
2. System findet automatisch Compliance-Relationships
3. Validation Queue zeigt pending Reviews
4. User approved Relationship
5. Document Detail zeigt validated Relationships

---

### 📊 Phase 4: Document Comparison & Analysis (2 Wochen)

**Ziel:** Multi-Document Comparison für Gap Analysis

#### 4.1 Document Comparison API (3-4 Tage)
**Priorität:** MEDIUM

**Aufgaben:**
- [ ] Verbessere `POST /api/relationships/compare`
- [ ] Detaillierter Comparison Report:
  - Section-by-Section Comparison
  - Identified Gaps (Norm requirements not in Guideline)
  - Conflicts (contradicting statements)
  - Overlap Analysis
  - Recommendations
- [ ] Optional: LLM-based Analysis für bessere Insights

**Dateien:**
```
api/routers/relationships.py       (update)
api/services/comparison_service.py (neu)
```

**Akzeptanzkriterien:**
- ✅ Comparison Report zeigt Gaps
- ✅ Conflicts klar markiert
- ✅ Recommendations nützlich

---

#### 4.2 Comparison UI (3-4 Tage)
**Priorität:** MEDIUM

**Aufgaben:**
- [ ] Comparison Page: `frontend/src/app/compare/page.tsx`
- [ ] Multi-select Documents für Comparison
- [ ] Side-by-side Viewer mit Highlights
- [ ] Gap Analysis Report
- [ ] Export als PDF/CSV

**Dateien:**
```
frontend/src/app/compare/page.tsx       (neu)
frontend/src/components/CompareView.tsx (neu)
frontend/src/components/GapReport.tsx   (neu)
```

**Akzeptanzkriterien:**
- ✅ Select 2+ Documents
- ✅ Side-by-side View
- ✅ Gaps visuell hervorgehoben
- ✅ Export funktioniert

---

### Phase 4 Milestone: **Document Comparison funktional**

**Demo:**
1. Select ISO 27001 Norm + Company Security Guideline
2. Run Comparison
3. Gap Report zeigt fehlende Requirements
4. Export Report als PDF

---

### ⚡ Phase 5: Real-time Updates & Polish (1 Woche)

**Ziel:** User Experience verbessern

#### 5.1 WebSocket Integration (2-3 Tage)
**Priorität:** LOW

**Aufgaben:**
- [ ] Frontend WebSocket Connection
- [ ] Progress Updates während Document Processing
- [ ] Real-time Notifications:
  - Document Processing Complete
  - New Relationships Detected
  - Validation Needed
- [ ] Toast Notifications

**Dateien:**
```
frontend/src/lib/websocket.ts           (neu)
frontend/src/hooks/useWebSocket.ts      (neu)
frontend/src/components/Notifications.tsx (neu)
```

**Akzeptanzkriterien:**
- ✅ Upload zeigt Progress in real-time
- ✅ Notification wenn Processing fertig
- ✅ Auto-Refresh wenn neue Relationships detected

---

#### 5.2 Dashboard Charts (2 Tage)
**Priorität:** LOW

**Aufgaben:**
- [ ] Chart Library (Recharts oder Chart.js)
- [ ] Dashboard Charts:
  - Document Upload Trend (last 30 days)
  - Document Types Distribution
  - Processing Status Breakdown
  - Relationship Types Distribution
- [ ] Responsive Design

**Dateien:**
```
frontend/src/components/charts/UploadTrendChart.tsx   (neu)
frontend/src/components/charts/TypeDistribution.tsx   (neu)
frontend/src/app/dashboard/page.tsx                   (update)
```

**Akzeptanzkriterien:**
- ✅ Dashboard zeigt 4 Charts
- ✅ Charts aktualisieren sich
- ✅ Responsive auf Mobile

---

### Phase 5 Milestone: **Production-Ready MVP**

---

## Prioritäten-Matrix

### MUST HAVE (Phase 1 + 2)
1. ✅ Qdrant Integration
2. ✅ Document Processing Pipeline
3. ✅ Dashboard Stats API Integration
4. ✅ Document List View
5. ✅ Semantic Search (Backend + Frontend)

### SHOULD HAVE (Phase 3)
6. ✅ Relationship Detection
7. ✅ Relationship Visualization
8. ✅ Validation Queue

### NICE TO HAVE (Phase 4 + 5)
9. ✅ Document Comparison
10. ✅ WebSocket Real-time Updates
11. ✅ Dashboard Charts

---

## Schnelle Wins - Was Sie JETZT fixen können (1-2 Tage)

### ✅ Quick Fix #1: Dashboard Stats (30 Minuten) - COMPLETED
**Datei:** `frontend/src/app/dashboard/page.tsx`

**Änderung:**
```typescript
// Zeile ~40: Statt hardcoded 0
const [stats, setStats] = useState({
  totalDocuments: 0,
  norms: 0,
  guidelines: 0,
});

// Nach Component Mount:
useEffect(() => {
  fetch('/api/documents/statistics/dashboard')
    .then(res => res.json())
    .then(data => setStats(data));
}, []);
```

**Result:** Dashboard zeigt echte Zahlen ✅

---

### ✅ Quick Fix #2: Search Alert entfernen (15 Minuten) - COMPLETED
**Datei:** `frontend/src/app/dashboard/page.tsx`

**Änderung:** Zeile 81
```typescript
// Statt alert():
const handleSearch = async () => {
  if (!searchQuery.trim()) return;

  const results = await fetch('/api/search', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: searchQuery }),
  }).then(r => r.json());

  // TODO: Zeige Results (Phase 2)
  console.log('Search results:', results);
};
```

**Result:** Search ruft echte API ab (auch wenn Results noch nicht angezeigt) ✅

---

### Quick Fix #3: Document Processing aktivieren (5 Minuten)
**Datei:** `api/routers/documents.py`

**Änderung:** Zeile 138 - Uncomment
```python
# BEFORE:
# TODO: Trigger Celery task for document processing
# from tasks import process_document
# process_document.delay(document.id)

# AFTER:
from api.tasks import process_document
process_document.delay(document.id)
```

**ABER:** Task implementieren Sie in Phase 1.2! Sonst Fehler.

---

## Geschätzte Zeitaufwände

| Phase | Aufwand | Priorität |
|-------|---------|-----------|
| Phase 1: Core Processing | 2-3 Wochen | CRITICAL |
| Phase 2: Semantic Search | 1-2 Wochen | HIGH |
| Phase 3: Relationships | 2-3 Wochen | MEDIUM |
| Phase 4: Comparison | 2 Wochen | MEDIUM |
| Phase 5: Polish | 1 Woche | LOW |
| **TOTAL** | **8-11 Wochen** | - |

**MVP (Must Have):** Phase 1 + 2 = **3-5 Wochen**

---

## Nächste Schritte - Was soll ich JETZT tun?

**Option A: Quick Wins (1-2 Tage)**
→ Ich fixe die 3 Quick Fixes oben
→ Dashboard Stats + Search API Integration
→ Sie sehen sofort Verbesserungen

**Option B: Phase 1 komplett (2-3 Wochen)**
→ Ich implementiere Qdrant Integration + Document Processing
→ Dann funktioniert die komplette Document Pipeline
→ Upload → Processing → Embeddings → READY

**Option C: Individuell**
→ Sie sagen mir welche Features am wichtigsten sind
→ Ich priorisiere entsprechend

**Welche Option bevorzugen Sie?**
