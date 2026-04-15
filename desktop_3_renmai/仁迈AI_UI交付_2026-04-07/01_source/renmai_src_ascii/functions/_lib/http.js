const BASE_HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "Referrer-Policy": "same-origin",
  "X-Content-Type-Options": "nosniff",
};

export class HttpError extends Error {
  constructor(status, message, details = {}) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export function json(data, init = {}) {
  const headers = new Headers(BASE_HEADERS);
  const extraHeaders = new Headers(init.headers || {});
  extraHeaders.forEach((value, key) => headers.set(key, value));
  return new Response(JSON.stringify(data), {
    ...init,
    headers,
  });
}

export function errorResponse(status, error, details = {}) {
  return json(
    {
      error,
      ...details,
    },
    { status },
  );
}

export async function readJson(request) {
  try {
    return await request.json();
  } catch (_) {
    throw new HttpError(400, "invalid_json");
  }
}

export function methodNotAllowed() {
  return errorResponse(405, "method_not_allowed");
}

export function handleRouteError(error) {
  if (error instanceof HttpError) {
    return errorResponse(error.status, error.message, error.details);
  }
  return errorResponse(500, "internal_error");
}

export function asTrimmedString(value, fallback = "") {
  return typeof value === "string" ? value.trim() : fallback;
}

export function asBoundedString(value, maxLength, fallback = "") {
  const text = asTrimmedString(value, fallback);
  return text.length > maxLength ? text.slice(0, maxLength) : text;
}

export function asStringArray(value, maxItems = 6, maxItemLength = 48) {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => asBoundedString(entry, maxItemLength))
    .filter(Boolean)
    .slice(0, maxItems);
}
