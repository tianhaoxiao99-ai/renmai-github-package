import { getTextModel, getVisionModel, isAiAvailable, isGeoAvailable } from "../_lib/ai.js";
import { enforceSameOrigin } from "../_lib/security.js";
import { handleRouteError, json } from "../_lib/http.js";

export async function onRequestGet(context) {
  try {
    enforceSameOrigin(context.request, context.env);

    const aiAvailable = isAiAvailable(context.env);
    const geoAvailable = isGeoAvailable(context.env);

    return json({
      aiAvailable,
      portraitAvailable: aiAvailable,
      geoAvailable,
      textModel: getTextModel(context.env),
      visionModel: getVisionModel(context.env),
    });
  } catch (error) {
    return handleRouteError(error);
  }
}
