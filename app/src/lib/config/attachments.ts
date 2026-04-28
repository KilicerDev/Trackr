export const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50 MB
export const MAX_ATTACHMENTS_PER_ENTITY = 20;

export const ALLOWED_MIME_TYPES = [
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'video/mp4',
  'video/quicktime',
  'video/webm',
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

export function isVideoType(mime: string): boolean {
  return mime.startsWith('video/');
}

export function getFileIcon(mime: string): string {
  if (isImageType(mime)) return 'image';
  if (isVideoType(mime)) return 'video';
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

export function validateAttachmentFiles(
  files: File[],
  maxFiles: number = MAX_ATTACHMENTS_PER_ENTITY,
): { valid: File[]; error: string | null } {
  let error: string | null = null;
  const valid: File[] = [];
  for (const file of files) {
    if (!isAllowedMimeType(file.type)) {
      error = `${file.name}: file type not allowed`;
      continue;
    }
    if (file.size > MAX_FILE_SIZE) {
      error = `${file.name}: exceeds ${formatFileSize(MAX_FILE_SIZE)} limit`;
      continue;
    }
    valid.push(file);
  }
  if (valid.length > maxFiles) {
    error = `Maximum ${maxFiles} files allowed`;
    return { valid: valid.slice(0, maxFiles), error };
  }
  return { valid, error };
}
