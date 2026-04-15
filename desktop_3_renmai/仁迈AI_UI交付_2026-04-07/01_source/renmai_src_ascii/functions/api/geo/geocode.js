import { enforceSameOrigin } from "../../_lib/security.js";
import { HttpError, asBoundedString, handleRouteError, json } from "../../_lib/http.js";
import { isGeoAvailable } from "../../_lib/ai.js";

const GEO_ENDPOINT = "https://api.geoapify.com/v1/geocode/search";

export async function onRequestGet(context) {
  try {
    enforceSameOrigin(context.request, context.env);
    if (!isGeoAvailable(context.env)) {
      throw new HttpError(503, "geo_service_unavailable");
    }

    const url = new URL(context.request.url);
    const query = asBoundedString(url.searchParams.get("q"), 120);
    if (!query) {
      throw new HttpError(400, "missing_query");
    }

    const upstreamUrl = new URL(GEO_ENDPOINT);
    upstreamUrl.searchParams.set("text", query);
    upstreamUrl.searchParams.set("lang", String(context.env.RENMAI_GEO_LANG || "zh-CN"));
    upstreamUrl.searchParams.set("limit", "1");
    upstreamUrl.searchParams.set("format", "json");
    upstreamUrl.searchParams.set("apiKey", String(context.env.GEOAPIFY_API_KEY).trim());

    const response = await fetch(upstreamUrl.toString(), {
      headers: {
        Accept: "application/json",
      },
    });
    if (!response.ok) {
      throw new HttpError(502, "geo_upstream_error");
    }

    const data = await response.json();
    const feature = Array.isArray(data?.results) ? data.results[0] : null;
    if (!feature?.lat || !feature?.lon) {
      return json({
        missing: true,
        query,
      });
    }

    return json({
      query,
      lat: Number(feature.lat),
      lng: Number(feature.lon),
      label: String(feature.formatted || feature.address_line1 || query),
    });
  } catch (error) {
    return handleRouteError(error);
  }
}
