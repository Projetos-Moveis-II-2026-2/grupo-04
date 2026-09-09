// Issue #27 — sugestão de carga via LLM (Gemini 2.5 Flash-Lite).
//
// Fluxo: JWT do usuário (auth: ["user"]) → consulta últimos sets do
// exercício via ctx.supabase (RLS-scoped) → rate limit 7 dias na
// ai_rate_limits (service_role) → prompt estruturado → Gemini → JSON.
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { withSupabase } from "@supabase/server";

const MODEL = "gemini-3.5-flash-lite";
const RATE_LIMIT_DAYS = 7;

interface LoadSuggestion {
  suggest_increase: boolean;
  recommendation: string;
  next_weight_kg: number | null;
  next_reps: number | null;
}

// callLLM isolada para trocar de provedor sem tocar no fluxo.
export async function callLLM(
  apiKey: string,
  prompt: string,
): Promise<LoadSuggestion> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.2,
        },
      }),
    },
  );
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Gemini HTTP ${res.status}: ${body.slice(0, 300)}`);
  }
  const data = await res.json();
  const text: string | undefined = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini sem texto na resposta");
  const parsed = JSON.parse(text) as LoadSuggestion;
  return {
    suggest_increase: Boolean(parsed.suggest_increase),
    recommendation: String(parsed.recommendation ?? ""),
    next_weight_kg: parsed.next_weight_kg ?? null,
    next_reps: parsed.next_reps ?? null,
  };
}

export function buildPrompt(
  exerciseName: string,
  sets: { weightKg: number | null; reps: number | null; completedAt: string }[],
): string {
  const history = sets
    .map((s) => `- ${s.completedAt}: ${s.weightKg ?? "?"}kg x ${s.reps ?? "?"} reps`)
    .join("\n");
  return [
    `Você é um treinador de musculação. Histórico recente do exercício "${exerciseName}":`,
    history,
    "",
    "Responda EXCLUSIVAMENTE com um JSON no formato:",
    '{"suggest_increase": boolean, "recommendation": string (1-2 frases, pt-BR), "next_weight_kg": number|null, "next_reps": number|null}',
    "Regra: aumente a carga somente se as últimas sessões completaram todas as reps com boa margem; senão sugira manter ou reduzir. Nunca sugira aumento maior que 10%.",
  ].join("\n");
}

export default {
  fetch: withSupabase({ auth: ["user"] }, async (req, ctx) => {
    let exerciseId: unknown;
    try {
      ({ exercise_id: exerciseId } = await req.json());
    } catch (_) {
      return Response.json({ error: "body inválido" }, { status: 400 });
    }
    if (typeof exerciseId !== "string" || exerciseId === "") {
      return Response.json({ error: "exercise_id obrigatório" }, { status: 400 });
    }
    const userId = ctx.userClaims!.id;
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return Response.json({ error: "IA não configurada" }, { status: 503 });
    }

    try {
      return await handle(userId, exerciseId, apiKey, ctx.supabase);
    } catch (e) {
      // O runtime emite apenas "Internal Server Error"; devolvemos a causa.
      const message = e instanceof Error ? e.message : String(e);
      console.error("suggest-load falhou:", message);
      return Response.json({ error: message }, { status: 500 });
    }
  }),
};

async function handle(
  userId: string,
  exerciseId: string,
  apiKey: string,
  rlsClient: SupabaseClient,
): Promise<Response> {
  // Rate limit 7 dias (service_role bypassa RLS na tabela de limites)
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: limit } = await admin
    .from("ai_rate_limits")
    .select("last_called_at")
    .eq("user_id", userId)
    .eq("exercise_id", exerciseId)
    .maybeSingle();
  if (limit) {
    const last = new Date(limit.last_called_at);
    const days = (Date.now() - last.getTime()) / 86_400_000;
    if (days < RATE_LIMIT_DAYS) {
      return Response.json(
        {
          error: "rate_limited",
          next_available_at: new Date(
            last.getTime() + RATE_LIMIT_DAYS * 86_400_000,
          ).toISOString(),
        },
        { status: 429 },
      );
    }
  }

  // Últimos 20 sets do exercício (RLS filtra pelo dono da sessão)
  const { data: sets, error } = await rlsClient
    .from("exercise_sets")
    .select("weight_kg, reps, created_at")
    .eq("exercise_id", exerciseId)
    .order("created_at", { ascending: false })
    .limit(20);
  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  const history = (sets ?? []).map((s) => ({
    weightKg: s.weight_kg as number | null,
    reps: s.reps as number | null,
    completedAt: s.created_at as string,
  }));
  if (history.length === 0) {
    return Response.json(
      { error: "sem histórico para este exercício" },
      { status: 404 },
    );
  }

  const { data: exercise } = await rlsClient
    .from("exercise_library")
    .select("name")
    .eq("id", exerciseId)
    .maybeSingle();
  const exerciseName = exercise?.name ?? `exercício ${exerciseId}`;
  const prompt = buildPrompt(exerciseName, history);
  const suggestion = await callLLM(apiKey, prompt);

  await admin.from("ai_rate_limits").upsert({
    user_id: userId,
    exercise_id: exerciseId,
    last_called_at: new Date().toISOString(),
  });

  return Response.json(suggestion);
}
