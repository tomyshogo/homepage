/**
 * Format a frontmatter date as YYYY-MM-DD.
 *
 * Markdown layout props hand us a real `Date` (YAML parses unquoted dates),
 * while `Astro.glob` hands us the JSON-serialised ISO string. Normalise both,
 * and fall back to the raw value if it is neither.
 */
export function formatDate(value: unknown): string {
  if (value == null) return "";

  const date = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) return String(value);

  return date.toISOString().slice(0, 10);
}
