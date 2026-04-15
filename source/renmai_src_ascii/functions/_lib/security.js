import { HttpError } from "./http.js";

function getAllowedOrigins(request, env) {
  const requestOrigin = new URL(request.url).origin;
  const configured = String(env.RENMAI_ALLOWED_ORIGINS || "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
  return new Set([requestOrigin, ...configured]);
}

export function enforceSameOrigin(request, env) {
  const allowedOrigins = getAllowedOrigins(request, env);
  const secFetchSite = request.headers.get("Sec-Fetch-Site");
  const origin = request.headers.get("Origin");
  const referer = request.headers.get("Referer");

  if (secFetchSite === "cross-site") {
    throw new HttpError(403, "cross_site_request_blocked");
  }

  if (origin && !allowedOrigins.has(origin)) {
    throw new HttpError(403, "origin_not_allowed");
  }

  if (referer) {
    let refererOrigin = "";
    try {
      refererOrigin = new URL(referer).origin;
    } catch (_) {
      throw new HttpError(403, "invalid_referer");
    }
    if (!allowedOrigins.has(refererOrigin)) {
      throw new HttpError(403, "referer_not_allowed");
    }
  }
}
