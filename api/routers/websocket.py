"""WebSocket router for real-time updates."""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict
from loguru import logger
import json

router = APIRouter()


class ConnectionManager:
    """Manager for WebSocket connections."""

    def __init__(self):
        """Initialize connection manager."""
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, client_id: str, websocket: WebSocket):
        """Connect a client.

        Args:
            client_id: Unique client ID
            websocket: WebSocket connection
        """
        await websocket.accept()
        self.active_connections[client_id] = websocket
        logger.info(f"Client connected: {client_id}")

    def disconnect(self, client_id: str):
        """Disconnect a client.

        Args:
            client_id: Client ID to disconnect
        """
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            logger.info(f"Client disconnected: {client_id}")

    async def send_message(self, client_id: str, message: dict):
        """Send message to a specific client.

        Args:
            client_id: Client ID
            message: Message to send
        """
        if client_id in self.active_connections:
            await self.active_connections[client_id].send_json(message)

    async def broadcast(self, message: dict):
        """Broadcast message to all connected clients.

        Args:
            message: Message to broadcast
        """
        for connection in self.active_connections.values():
            await connection.send_json(message)


manager = ConnectionManager()


@router.websocket("/progress/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """WebSocket endpoint for upload/processing progress.

    Args:
        websocket: WebSocket connection
        client_id: Unique client identifier
    """
    await manager.connect(client_id, websocket)

    try:
        while True:
            # Receive messages from client (if any)
            data = await websocket.receive_text()

            # Echo back (for testing)
            await websocket.send_json({
                "type": "echo",
                "message": f"Received: {data}"
            })

    except WebSocketDisconnect:
        manager.disconnect(client_id)
    except Exception as e:
        logger.error(f"WebSocket error for client {client_id}: {e}")
        manager.disconnect(client_id)


async def send_progress_update(
    client_id: str,
    filename: str,
    status: str,
    progress: float,
    message: str = None
):
    """Send progress update to a client.

    Args:
        client_id: Client ID
        filename: Filename being processed
        status: Current status
        progress: Progress percentage (0-100)
        message: Optional message
    """
    await manager.send_message(client_id, {
        "type": "progress",
        "filename": filename,
        "status": status,
        "progress": progress,
        "message": message
    })
