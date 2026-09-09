// Issue #28 — fallback LLM para substituição de exercícios (camada 2).
//
// Só é chamada quando a busca estruturada (RPC find_substitutes,
// migração 006) retorna 0 resultados. Rate limit COMPARTILHADO:
// ai_rate_limits com exercise_id = 'assistant' (1 fallback por
// usuário por semana, cláusula da issue #28).
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { withSupabase } from "@supabase/server";

const MODEL = "gemini-3.5-flash-lite";
const RATE_LIMIT_DAYS = 7;
const ASSISTANT_KEY = "assistant";

export async function callLLM(apiKey: string, prompt: string): Promise<string> {
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
  return text;
}

export function buildPrompt(
  exerciseName: string,
  equipment: string | null,
  muscles: string[],
): string {
  return [
    `Você é um treinador de musculação. O exercício "${exerciseName}" (equipamento: ${equipment ?? "livre"}; músculos primários: ${muscles.join(", ")}) não pôde ser realizado.`,
    "",
    `Sugira 3 exercícios alternativos que trabalhem os MESMOS músculos primários com equipamento DIFERENTE de ${equipment ?? "o atual"}.`,
    "",
    'IMPORTANTE: use os nomes dos exercícios EM INGLÊS como no catálogo free-exercise-db (ex.: "Barbell Bench Press - Medium Grip", "Machine Chest Press", "Cable Flyes"), pois eles serão buscados por nome no catálogo.',
    "",
    "Responda EXCLUSIVAMENTE com JSON no formato:",
    '{"substitutes":[{"name":"nome em inglês do catálogo","equipment":"equipamento","reason":"1 frase em pt-BR"}]}',
  ].join("\n");
}

interface Substitute {
  name: string;
  equipment: string | null;
  reason: string;
  matched_id: string | null;
  matched_external_id: string | null;
  matched_name: string | null;
  image_url: string | null;
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
      const message = e instanceof Error ? e.message : String(e);
      console.error("suggest-substitute falhou:", message);
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
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: exercise, error } = await rlsClient
    .from("exercise_library")
    .select("name, equipment, primary_muscles")
    .eq("id", exerciseId)
    .maybeSingle();
  if (error) return Response.json({ error: error.message }, { status: 500 });
  if (!exercise) {
    return Response.json({ error: "exercício não encontrado" }, { status: 404 });
  }

  const { data: limit } = await admin
    .from("ai_rate_limits")
    .select("last_called_at")
    .eq("user_id", userId)
    .eq("exercise_id", ASSISTANT_KEY)
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

  const prompt = buildPrompt(
    exercise.name as string,
    exercise.equipment as string | null,
    (exercise.primary_muscles as string[] | null) ?? [],
  );
  const raw = await callLLM(apiKey, prompt);
  const parsed = JSON.parse(raw) as { substitutes?: Partial<Substitute>[] };

  // Resolve os nomes sugeridos contra o catálogo (IDs + imagem)
  const substitutes: Substitute[] = [];
  for (const s of (parsed.substitutes ?? []).slice(0, 3)) {
    const name = String(s.name ?? "");
    if (!name) continue;
    const { data: match } = await rlsClient
      .from("exercise_library")
      .select("id, external_id, name, equipment, image_urls")
      .ilike("name", `%${name}%`)
      .limit(1);
    const m = match?.[0];
    substitutes.push({
      name,
      equipment: (s.equipment ?? (m?.equipment as string | null)) || null,
      reason: String(s.reason ?? ""),
      matched_id: m ? (m.id as string) : null,
      matched_external_id: m ? (m.external_id as string) : null,
      matched_name: m ? (m.name as string) : null,
      image_url:
        m && Array.isArray(m.image_urls) && m.image_urls.length > 0
          ? `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/${m.image_urls[0]}`
          : null,
    });
  }

  await admin.from("ai_rate_limits").upsert({
    user_id: userId,
    exercise_id: ASSISTANT_KEY,
    last_called_at: new Date().toISOString(),
  });

  return Response.json({ substitutes });
}
