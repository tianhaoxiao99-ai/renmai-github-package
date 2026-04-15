import {
  extractAiText,
  getTextModel,
  isAiAvailable,
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

const RELATION_TYPES = new Set(["friend", "family", "partner", "colleague", "mentor", "classmate"]);
const IMPORTANCE_LEVELS = new Set(["regular", "important"]);

function normalizePayload(body) {
  const relationType = asBoundedString(body?.relationType, 24);
  const importanceLevel = asBoundedString(body?.importanceLevel, 24);
  const payload = {
    targetAlias: asBoundedString(body?.targetAlias, 24, "{{target}}") || "{{target}}",
    relationType: RELATION_TYPES.has(relationType) ? relationType : "friend",
    importanceLevel: IMPORTANCE_LEVELS.has(importanceLevel) ? importanceLevel : "regular",
    priorityRank: Math.max(1, Math.min(9, Number(body?.priorityRank || 1) || 1)),
    weeklyFrequency: Math.max(0, Math.min(21, Number(body?.weeklyFrequency || 0) || 0)),
    monthlyDepth: Math.max(0, Math.min(16, Number(body?.monthlyDepth || 0) || 0)),
    scenario: asBoundedString(body?.scenario, 400),
    intent: asBoundedString(body?.intent, 24, "问候") || "问候",
    occasion: asBoundedString(body?.occasion, 24, "日常") || "日常",
    portraitTags: asStringArray(body?.portraitTags, 6, 24),
    giftBudgetLabel: asBoundedString(body?.giftBudgetLabel, 64),
  };
  if (!payload.scenario) {
    throw new HttpError(400, "missing_scenario");
  }
  return payload;
}

function buildPrompt(payload) {
  return [
    "你是一个隐私优先的人脉助手。",
    "你只能基于给定的关系类型、交流频率、重要程度、送礼区间和少量风格标签来生成建议。",
    "禁止推断敏感身份、种族、宗教、疾病、收入、年龄或住址。",
    "如果要提到对方，必须使用字面量占位符 {{target}}，不要擅自生成真实姓名。",
    "输出必须是一个 JSON 对象，字段为 summary、reply、giftAdvice、budgetText、needs。",
    "needs 必须是字符串数组，给 2 到 5 条。",
    `对象占位符：${payload.targetAlias}`,
    `关系类型：${payload.relationType}`,
    `重要层级：${payload.importanceLevel}`,
    `重要排序：${payload.priorityRank}`,
    `每周交流频次：${payload.weeklyFrequency}`,
    `每月深度互动：${payload.monthlyDepth}`,
    `沟通目的：${payload.intent}`,
    `当前场景：${payload.occasion}`,
    `礼物价值区间：${payload.giftBudgetLabel || "按当前场景稳妥判断"}`,
    `画像标签：${payload.portraitTags.join("、") || "暂无"}`,
    `用户任务：${payload.scenario}`,
    "语气要求：温和、自然、具体、不过度讨好，像真实的人在表达。",
  ].join("\n");
}

function normalizeModelResponse(parsed, fallbackBudgetLabel) {
  return {
    summary: asBoundedString(parsed?.summary, 180),
    reply: asBoundedString(parsed?.reply, 600),
    giftAdvice: asBoundedString(parsed?.giftAdvice, 220),
    budgetText: asBoundedString(parsed?.budgetText, 80, fallbackBudgetLabel || "待结合礼物页查看"),
    needs: asStringArray(parsed?.needs, 5, 48),
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

    let aiResponse;
    try {
      aiResponse = await context.env.AI.run(getTextModel(context.env), {
        messages: [
          {
            role: "system",
            content:
              "You are a privacy-first Chinese relationship assistant. Reply with JSON only.",
          },
          {
            role: "user",
            content: buildPrompt(payload),
          },
        ],
        temperature: 0.6,
        max_tokens: 700,
      });
    } catch (error) {
      const failure = modelFailureDetails(error);
      throw new HttpError(failure.status, failure.error, failure.hint ? { hint: failure.hint } : {});
    }

    const text = extractAiText(aiResponse);
    const parsed = parseJsonObject(text);
    const response = normalizeModelResponse(parsed, payload.giftBudgetLabel);
    if (!response.reply) {
      throw new HttpError(502, "empty_model_reply");
    }

    return json(response);
  } catch (error) {
    return handleRouteError(error);
  }
}
