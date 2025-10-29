# EchoGraph API Reference

## Base URL

```
http://localhost:8000/api
```

## Authentication

EchoGraph uses JWT (JSON Web Token) authentication.

### Login

```http
POST /api/auth/token
Content-Type: application/x-www-form-urlencoded

username=user@example.com&password=yourpassword
```

**Response:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### Using Authentication

Include the token in the Authorization header:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Documents

### Upload Document

```http
POST /api/documents/upload
Authorization: Bearer {token}
Content-Type: multipart/form-data

file: (binary)
title: "ISO 27001 Standard"
document_type: "norm"
author: "ISO"
category: "Security"
description: "Information security standard"
version: "2022"
```

**Response:**

```json
{
  "id": 1,
  "title": "ISO 27001 Standard",
  "document_type": "norm",
  "file_path": "echograph-documents/uuid.pdf",
  "file_size": 1024000,
  "file_type": "pdf",
  "author": "ISO",
  "category": "Security",
  "tags": [],
  "description": "Information security standard",
  "version": "2022",
  "status": "processing",
  "upload_date": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}
```

### List Documents

```http
GET /api/documents?page=1&page_size=20&document_type=norm&search=ISO
Authorization: Bearer {token}
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| page | integer | Page number (default: 1) |
| page_size | integer | Items per page (default: 20, max: 100) |
| document_type | string | Filter by type: "norm" or "guideline" |
| category | string | Filter by category |
| status | string | Filter by status |
| search | string | Search in title, author, description |

**Response:**

```json
{
  "total": 150,
  "page": 1,
  "page_size": 20,
  "documents": [
    {
      "id": 1,
      "title": "ISO 27001 Standard",
      "document_type": "norm",
      "status": "ready",
      "upload_date": "2025-01-15T10:30:00Z"
    }
  ]
}
```

### Get Document

```http
GET /api/documents/{id}
Authorization: Bearer {token}
```

**Response:**

```json
{
  "id": 1,
  "title": "ISO 27001 Standard",
  "document_type": "norm",
  "file_path": "echograph-documents/uuid.pdf",
  "status": "ready",
  "chunks": [
    {
      "id": 1,
      "chunk_index": 0,
      "chunk_text": "Information security management...",
      "char_count": 512,
      "section_title": "Introduction",
      "page_number": 1
    }
  ],
  "upload_date": "2025-01-15T10:30:00Z",
  "processed_date": "2025-01-15T10:35:00Z"
}
```

### Update Document

```http
PUT /api/documents/{id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "Updated Title",
  "category": "Compliance",
  "tags": ["security", "ISO"]
}
```

### Delete Document

```http
DELETE /api/documents/{id}
Authorization: Bearer {token}
```

**Response:** 204 No Content

### Get Statistics

```http
GET /api/documents/statistics/dashboard
Authorization: Bearer {token}
```

**Response:**

```json
{
  "total_documents": 150,
  "total_norms": 75,
  "total_guidelines": 75,
  "total_relationships": 450,
  "pending_validations": 23,
  "approved_relationships": 380,
  "rejected_relationships": 47
}
```

## Relationships

### Compare Documents

```http
POST /api/relationships/compare
Authorization: Bearer {token}
Content-Type: application/json

{
  "document_ids": [1, 2, 3],
  "threshold": 0.7
}
```

**Response:**

```json
{
  "results": [
    {
      "document_id": 1,
      "document_title": "ISO 27001",
      "document_type": "norm",
      "relationships": [
        {
          "id": 1,
          "source_doc_id": 1,
          "target_doc_id": 2,
          "relationship_type": "compliance",
          "confidence": 85.5,
          "summary": "Security policy aligns with ISO requirements",
          "validation_status": "approved",
          "created_at": "2025-01-15T11:00:00Z"
        }
      ]
    }
  ],
  "total_relationships": 12
}
```

### Get Document Relationships

```http
GET /api/relationships/document/{document_id}?validation_status=approved
Authorization: Bearer {token}
```

**Response:**

```json
[
  {
    "id": 1,
    "source_doc_id": 1,
    "target_doc_id": 2,
    "relationship_type": "compliance",
    "confidence": 85.5,
    "summary": "Security policy aligns with ISO requirements",
    "validation_status": "approved",
    "source_document": {
      "id": 1,
      "title": "ISO 27001",
      "document_type": "norm"
    },
    "target_document": {
      "id": 2,
      "title": "Security Policy",
      "document_type": "guideline"
    }
  }
]
```

### Validate Relationship

```http
POST /api/relationships/{id}/validate
Authorization: Bearer {token}
Content-Type: application/json

{
  "validation_status": "approved",
  "validation_notes": "Verified compliance alignment"
}
```

**Requires:** Reviewer role

### Get Pending Relationships

```http
GET /api/relationships/pending/review?limit=50
Authorization: Bearer {token}
```

**Requires:** Reviewer role

## Search

### Semantic Search

```http
POST /api/search
Authorization: Bearer {token}
Content-Type: application/json

{
  "query": "data protection requirements",
  "document_type": "norm",
  "limit": 10,
  "threshold": 0.6
}
```

**Response:**

```json
{
  "query": "data protection requirements",
  "results": [
    {
      "document_id": 1,
      "document_title": "ISO 27001",
      "document_type": "norm",
      "chunk_id": 15,
      "chunk_text": "Data protection measures must include...",
      "similarity": 0.87
    }
  ],
  "total": 8
}
```

## WebSocket

### Upload Progress

```javascript
const ws = new WebSocket('ws://localhost:8000/api/ws/progress/{client_id}')

ws.onmessage = (event) => {
  const data = JSON.parse(event.data)
  console.log(data)
  // {
  //   "type": "progress",
  //   "filename": "document.pdf",
  //   "status": "extracting",
  //   "progress": 45.5,
  //   "message": "Extracting text from PDF"
  // }
}
```

## Error Responses

### Error Format

```json
{
  "detail": "Error message here"
}
```

### Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 204 | No Content |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Validation Error |
| 500 | Internal Server Error |

### Validation Error Example

```json
{
  "detail": [
    {
      "loc": ["body", "title"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

## Rate Limiting

- **Anonymous**: 100 requests/hour
- **Authenticated**: 1000 requests/hour
- **Upload**: 10 files/hour

Rate limit headers:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642262400
```

## Pagination

All list endpoints support pagination:

```json
{
  "total": 150,
  "page": 1,
  "page_size": 20,
  "items": [...]
}
```

## Filtering & Sorting

Use query parameters for filtering:

```http
GET /api/documents?category=Security&status=ready&sort=-upload_date
```

Sort syntax:
- Ascending: `sort=field`
- Descending: `sort=-field`

## Interactive API Documentation

Visit http://localhost:8000/docs for interactive Swagger UI documentation.

## Code Examples

### Python

```python
import requests

# Login
response = requests.post(
    'http://localhost:8000/api/auth/token',
    data={'username': 'user@example.com', 'password': 'password'}
)
token = response.json()['access_token']

# Upload document
headers = {'Authorization': f'Bearer {token}'}
files = {'file': open('document.pdf', 'rb')}
data = {
    'title': 'Test Document',
    'document_type': 'norm'
}
response = requests.post(
    'http://localhost:8000/api/documents/upload',
    headers=headers,
    files=files,
    data=data
)
document = response.json()
```

### JavaScript

```javascript
// Login
const loginResponse = await fetch('http://localhost:8000/api/auth/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: 'username=user@example.com&password=password'
})
const { access_token } = await loginResponse.json()

// Upload document
const formData = new FormData()
formData.append('file', fileInput.files[0])
formData.append('title', 'Test Document')
formData.append('document_type', 'norm')

const uploadResponse = await fetch('http://localhost:8000/api/documents/upload', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${access_token}` },
  body: formData
})
const document = await uploadResponse.json()
```

### cURL

```bash
# Login
TOKEN=$(curl -X POST "http://localhost:8000/api/auth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=user@example.com&password=password" \
  | jq -r '.access_token')

# Upload document
curl -X POST "http://localhost:8000/api/documents/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@document.pdf" \
  -F "title=Test Document" \
  -F "document_type=norm"
```
