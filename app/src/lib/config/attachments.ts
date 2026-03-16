export const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50 MB
export const MAX_ATTACHMENTS_PER_ENTITY = 20;

export const ALLOWED_MIME_TYPES = [
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'text/csv',
] as const;

export function isImageType(mime: string): boolean {
  return mime.startsWith('image/');
}

export function isPdfType(mime: string): boolean {
  return mime === 'application/pdf';
}

export function getFileIcon(mime: string): string {
  if (isImageType(mime)) return 'image';
  if (isPdfType(mime)) return 'file-text';
  if (mime.includes('spreadsheet') || mime.includes('excel') || mime === 'text/csv') return 'table';
  if (mime.includes('presentation') || mime.includes('powerpoint')) return 'presentation';
  if (mime.includes('word') || mime.includes('document') || mime === 'text/plain') return 'file-text';
  return 'file';
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function isAllowedMimeType(mime: string): boolean {
  return (ALLOWED_MIME_TYPES as readonly string[]).includes(mime);
}
