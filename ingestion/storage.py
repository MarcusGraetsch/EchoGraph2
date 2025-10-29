"""Storage utilities for MinIO/S3 integration."""

from pathlib import Path
from typing import Optional, BinaryIO
from minio import Minio
from minio.error import S3Error
from loguru import logger

from .config import settings


class StorageClient:
    """Client for interacting with MinIO/S3 storage."""

    def __init__(self):
        """Initialize MinIO client."""
        self.client = Minio(
            settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_use_ssl
        )
        self.bucket = settings.minio_bucket
        self._ensure_bucket()

    def _ensure_bucket(self):
        """Create bucket if it doesn't exist."""
        try:
            if not self.client.bucket_exists(self.bucket):
                self.client.make_bucket(self.bucket)
                logger.info(f"Created bucket: {self.bucket}")
        except S3Error as e:
            logger.error(f"Error ensuring bucket exists: {e}")

    def upload_file(
        self,
        file_path: Path,
        object_name: Optional[str] = None,
        content_type: Optional[str] = None
    ) -> Optional[str]:
        """Upload a file to storage.

        Args:
            file_path: Path to file to upload
            object_name: Object name in storage (defaults to filename)
            content_type: Content type of the file

        Returns:
            Object name if successful, None otherwise
        """
        if object_name is None:
            object_name = file_path.name

        try:
            self.client.fput_object(
                self.bucket,
                object_name,
                str(file_path),
                content_type=content_type
            )
            logger.info(f"Uploaded {file_path} as {object_name}")
            return object_name

        except S3Error as e:
            logger.error(f"Error uploading file: {e}")
            return None

    def upload_fileobj(
        self,
        file_data: BinaryIO,
        object_name: str,
        length: int,
        content_type: Optional[str] = None
    ) -> Optional[str]:
        """Upload file object to storage.

        Args:
            file_data: File object to upload
            object_name: Object name in storage
            length: Length of file data
            content_type: Content type of the file

        Returns:
            Object name if successful, None otherwise
        """
        try:
            self.client.put_object(
                self.bucket,
                object_name,
                file_data,
                length,
                content_type=content_type
            )
            logger.info(f"Uploaded file object as {object_name}")
            return object_name

        except S3Error as e:
            logger.error(f"Error uploading file object: {e}")
            return None

    def download_file(
        self,
        object_name: str,
        file_path: Path
    ) -> bool:
        """Download a file from storage.

        Args:
            object_name: Object name in storage
            file_path: Path to save downloaded file

        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.fget_object(
                self.bucket,
                object_name,
                str(file_path)
            )
            logger.info(f"Downloaded {object_name} to {file_path}")
            return True

        except S3Error as e:
            logger.error(f"Error downloading file: {e}")
            return False

    def delete_file(self, object_name: str) -> bool:
        """Delete a file from storage.

        Args:
            object_name: Object name in storage

        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.remove_object(self.bucket, object_name)
            logger.info(f"Deleted {object_name}")
            return True

        except S3Error as e:
            logger.error(f"Error deleting file: {e}")
            return False

    def get_file_url(self, object_name: str, expires: int = 3600) -> Optional[str]:
        """Get a presigned URL for a file.

        Args:
            object_name: Object name in storage
            expires: URL expiration time in seconds (default: 1 hour)

        Returns:
            Presigned URL if successful, None otherwise
        """
        try:
            url = self.client.presigned_get_object(
                self.bucket,
                object_name,
                expires=expires
            )
            return url

        except S3Error as e:
            logger.error(f"Error generating presigned URL: {e}")
            return None
