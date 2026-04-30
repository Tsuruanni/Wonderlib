// Shared helper for resolving API keys / generation params from either
// Deno env vars (Supabase Edge secrets) or the `system_settings` table.
//
// Lookup order:
//   1. Deno.env.get(envKey) — fast path, what Supabase secrets provides.
//   2. system_settings.value where key = dbKey — admin-editable fallback.
//
// Returns null if neither resolves to a non-empty value, which the caller
// should treat as "not configured" and surface a clear 500 to the operator.

import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

export async function getApiConfig(
  dbKey: string,
  envKey: string,
  supabase?: SupabaseClient,
): Promise<string | null> {
  // 1. Env var first — this is the existing behavior, no DB hit when set.
  const envValue = Deno.env.get(envKey);
  if (envValue && envValue.trim().length > 0) {
    return envValue;
  }

  // 2. system_settings fallback. value is JSONB; we coerce to string.
  // Caller may pass an existing client; otherwise create an anon one
  // (system_settings has a public-read RLS policy).
  const client = supabase ?? createAnonClient();
  try {
    const { data, error } = await client
      .from("system_settings")
      .select("value")
      .eq("key", dbKey)
      .maybeSingle();

    if (error || !data) return null;

    const v = data.value;
    if (v == null) return null;
    if (typeof v === "string") {
      return v.trim().length > 0 ? v : null;
    }
    return String(v);
  } catch (_e) {
    return null;
  }
}

/// Convenience: build a minimal anon Supabase client suitable for reading
/// settings (RLS allows public read on system_settings). Edge functions that
/// already create a service-role client can pass that one in instead.
export function createAnonClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  return createClient(url, key);
}
