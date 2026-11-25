import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: ["user"] }, async (_req, ctx) => {
    const userId = ctx.userClaims!.id;

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Limpa registros órfãos em ai_rate_limits (sem FK, não cascateiam)
    await admin.from("ai_rate_limits").delete().eq("user_id", userId);

    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) {
      console.error("delete-account failed:", error.message);
      return Response.json({ error: error.message }, { status: 500 });
    }

    return Response.json({ deleted: true });
  }),
};
