import { HttpError } from "./http.js";

export const DEFAULT_TEXT_MODEL = "@cf/meta/llama-3.1-8b-instruct-fast";
export const DEFAULT_VISION_MODEL = "@cf/meta/llama-3.2-11b-vision-instruct";

export function getTextModel(env) {
  return String(env.RENMAI_TEXT_MODEL || DEFAULT_TEXT_MODEL).trim() || DEFAULT_TEXT_MODEL;
}

export function getVisionModel(env) {
  return String(env.RENMAI_VISION_MODEL || DEFAULT_VISION_MODEL).trim() || DEFAULT_VISION_MODEL;
}

export function isAiAvailable(env) {
  return Boolean(env?.AI);
}

export function isGeoAvailable(env) {
  return Boolean(String(env.GEOAPIFY_API_KEY || "").trim());
}

export async function maybeAcceptMetaVisionTerms(env) {
  if (!isAiAvailable(env)) return;
  if (String(env.RENMAI_AUTO_ACCEPT_META_LICENSE || "false").toLowerCase() !== "true") return;

  try {
    await env.AI.run(getVisionModel(env), {
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: "agree" }],
        },
      ],
      max_tokens: 4,
    });
  } catch (error) {
    const message = String(error?.message || "");
    if (!/agree|license|terms/i.test(message)) {
      throw error;
    }
  }
}

export function extractAiText(payload) {
  if (typeof payload === "string") return payload;
  if (!payload || typeof payload !== "object") return "";
  if (typeof payload.response === "string") return payload.response;
  if (typeof payload.result?.response === "string") return payload.result.response;
  if (typeof payload.output_text === "string") return payload.output_text;
  if (Array.isArray(payload.output)) {
    const joined = payload.output
      .flatMap((entry) => entry?.content || entry?.contents || [])
      .map((entry) => entry?.text || "")
      .join("\n")
      .trim();
    if (joined) return joined;
  }
  if (Array.isArray(payload.response)) {
    const joined = payload.response
      .map((entry) => entry?.text || entry?.content || "")
      .join("\n")
      .trim();
    if (joined) return joined;
  }
  if (typeof payload.result === "string") return payload.result;
  return "";
}

export function parseJsonObject(text) {
  const cleaned = String(text || "")
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  const matched = cleaned.match(/\{[\s\S]*\}/);
  if (!matched) {
    throw new HttpError(502, "invalid_model_json");
  }
  try {
    return JSON.parse(matched[0]);
  } catch (_) {
    throw new HttpError(502, "invalid_model_json");
  }
}

export function modelFailureDetails(error) {
  const message = String(error?.message || "");
  if (/agree|license|terms/i.test(message)) {
    return {
      status: 503,
      error: "vision_terms_not_accepted",
      hint: "Please accept the Meta model terms once in the Cloudflare AI playground or enable RENMAI_AUTO_ACCEPT_META_LICENSE for development.",
    };
  }
  return {
    status: 502,
    error: "upstream_model_error",
  };
}
