export function indexDocument(sourceType: string, sourceId: string) {
  fetch("/api/index-document", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ source_type: sourceType, source_id: sourceId }),
  }).catch(() => {});
}

export function deleteDocument(sourceType: string, sourceId: string) {
  fetch("/api/delete-document", {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ source_type: sourceType, source_id: sourceId }),
  }).catch(() => {});
}
