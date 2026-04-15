import {
  extractAiText,
  getVisionModel,
  isAiAvailable,
  maybeAcceptMetaVisionTerms,
  modelFailureDetails,
  parseJsonObject,
} from "../../_lib/ai.js";
import {
  HttpError,
  asBoundedString,
  asStringArray,
  handleRouteError,
  json,
  readJson,
} from "../../_lib/http.js";
import { enforceSameOrigin } from "../../_lib/security.js";

const APPEARANCE_LABELS = new Set([
  "专业稳重",
  "亲和自然",
  "精致仪式",
  "文艺细腻",
  "活力社交",
  "简洁克制",
]);

function normalizePayload(body) {
  const imageBase64 = asBoundedString(body?.imageBase64, 2_200_000);
  if (!imageBase64) {
    throw new HttpError(400, "missing_image");
  }
  return {
    relationshipAlias: asBoundedString(body?.relationshipAlias, 24, "{{target}}") || "{{target}}",
    imageBase64,
  };
}

function buildPrompt(payload) {
  return [
    "你是一个保守的人像风格辅助分析器。",
    "你只可以根据外在风格给出印象标签、沟通提示和送礼提示。",
    "禁止推断年龄、职业、收入、种族、宗教、疾病、性取向、住址等敏感属性。",
    "输出必须是一个 JSON 对象，字段为 appearanceLabel、summary、styleTags、communicationHints、giftHints、traitTags。",
    "appearanceLabel 只能从以下标签里选择一个：专业稳重、亲和自然、精致仪式、文艺细腻、活力社交、简洁克制。",
    "styleTags、communicationHints、giftHints 为字符串数组，各给 2 到 3 条。",
    "traitTags 只能从 practical、sentimental、comfort、formal、novelty、social 中选 2 到 3 个。",
    `联系人占位符：${payload.relationshipAlias}`,
  ].join("\n");
}

function normalizeModelResponse(parsed) {
  const appearanceLabel = asBoundedString(parsed?.appearanceLabel, 24, "亲和自然");
  return {
    appearanceLabel: APPEARANCE_LABELS.has(appearanceLabel) ? appearanceLabel : "亲和自然",
    summary: asBoundedString(parsed?.summary, 220),
    styleTags: asStringArray(parsed?.styleTags, 4, 24),
    communicationHints: asStringArray(parsed?.communicationHints, 4, 36),
    giftHints: asStringArray(parsed?.giftHints, 4, 36),
    traitTags: asStringArray(parsed?.traitTags, 3, 24),
    source: "model",
  };
}

export async function onRequestPost(context) {
  try {
    enforceSameOrigin(context.request, context.env);
    if (!isAiAvailable(context.env)) {
      throw new HttpError(503, "ai_service_unavailable");
    }

    const body = await readJson(context.request);
    const payload = normalizePayload(body);
    await maybeAcceptMetaVisionTerms(context.env);

    let aiResponse;
    try {
      aiResponse = await context.env.AI.run(getVisionModel(context.env), {
        messages: [
          {
            role: "system",
            content: "You are a privacy-first portrait style assistant. Reply with JSON only.",
          },
          {
            role: "user",
            content: [
              { type: "text", text: buildPrompt(payload) },
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: payload.imageBase64,
                },
              },
            ],
          },
        ],
        temperature: 0.3,
        max_tokens: 500,
      });
    } catch (error) {
      const failure = modelFailureDetails(error);
      throw new HttpError(failure.status, failure.error, failure.hint ? { hint: failure.hint } : {});
    }

    const text = extractAiText(aiResponse);
    const parsed = parseJsonObject(text);
    const response = normalizeModelResponse(parsed);
    if (!response.summary) {
      throw new HttpError(502, "empty_model_reply");
    }

    return json(response);
  } catch (error) {
    return handleRouteError(error);
  }
}
