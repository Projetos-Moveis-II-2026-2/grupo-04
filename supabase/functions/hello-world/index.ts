// Issue #26 — hello-world com autenticação JWT de usuário obrigatória.
// A API key do Gemini fica como secret (`GEMINI_API_KEY`) e nunca no código;
// aqui apenas provamos que secrets chegam via Deno.env (bool, sem vazar valor).
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: ["user"] }, async (req, ctx) => {
    // `auth: ["user"]` garante: sem Bearer token válido → 401 antes daqui.
    const geminiConfigured = Boolean(Deno.env.get("GEMINI_API_KEY"));

    let name = "world";
    try {
      const body = await req.json();
      if (typeof body?.name === "string" && body.name.length > 0) {
        name = body.name;
      }
    } catch (_) {
      // corpo vazio/inválido usa o default
    }

    return Response.json({
      message: `Hello ${name}!`,
      user_id: ctx.userClaims?.id,
      gemini_api_key_configured: geminiConfigured,
    });
  }),
};
