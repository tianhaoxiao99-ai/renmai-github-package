import { enforceSameOrigin } from "../_lib/security.js";
import { handleRouteError, json } from "../_lib/http.js";

function asPublicValue(value) {
  return typeof value === "string" ? value.trim() : "";
}

export async function onRequestGet(context) {
  try {
    enforceSameOrigin(context.request, context.env);

    const supabaseUrl = asPublicValue(context.env.PUBLIC_SUPABASE_URL);
    const supabaseAnonKey =
      asPublicValue(context.env.PUBLIC_SUPABASE_ANON_KEY)
      || asPublicValue(context.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY);

    return json({
      supabaseEnabled: Boolean(supabaseUrl && supabaseAnonKey),
      supabaseUrl,
      supabaseAnonKey,
    });
  } catch (error) {
    return handleRouteError(error);
  }
}
