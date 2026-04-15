import { createClient } from "npm:@supabase/supabase-js@2";

type AlertRow = {
  id: number;
  source: string;
  alert_code: string;
  severity: "warning" | "critical";
  message: string;
  context: Record<string, unknown> | null;
  first_seen_at: string;
  last_seen_at: string;
  occurrence_count: number;
  last_notified_at: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-ingestion-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function toDateValue(value: string | null | undefined): number {
  if (!value) return 0;
  const ts = Date.parse(value);
  return Number.isFinite(ts) ? ts : 0;
}

function formatAlertLine(alert: AlertRow): string {
  const emoji = alert.severity === "critical" ? "[CRITICAL]" : "[WARNING]";
  return `${emoji} ${alert.alert_code}: ${alert.message} (seen ${alert.occurrence_count}x)`;
}

function buildPayload(webhookUrl: string, source: string, alerts: AlertRow[]): unknown {
  const lines = alerts.map((alert) => formatAlertLine(alert));
  const header = `Ingestion alerts for ${source}: ${alerts.length} pending`;
  const text = `${header}\n${lines.join("\n")}`;

  if (webhookUrl.includes("discord.com/api/webhooks")) {
    return { content: text.slice(0, 1900) };
  }

  if (webhookUrl.includes("hooks.slack.com") || webhookUrl.includes("slack.com")) {
    return { text };
  }

  return {
    source,
    text,
    alerts,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey =
      Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const ingestionSecret = Deno.env.get("INGESTION_SHARED_SECRET");
    const webhookUrl = Deno.env.get("INGESTION_ALERT_WEBHOOK_URL");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing required Supabase env vars");
    }

    if (ingestionSecret) {
      const provided = req.headers.get("x-ingestion-secret");
      if (provided !== ingestionSecret) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const body = (await req.json().catch(() => ({}))) as { source?: string };
    const source = body.source?.trim() || "sportmonks-enrichment";

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data, error } = await supabase
      .from("ingestion_alert_events")
      .select(
        "id, source, alert_code, severity, message, context, first_seen_at, last_seen_at, occurrence_count, last_notified_at",
      )
      .eq("source", source)
      .eq("is_active", true)
      .order("severity", { ascending: false })
      .order("last_seen_at", { ascending: false });

    if (error) {
      throw new Error(`Failed to read alerts: ${error.message}`);
    }

    const rows = (data ?? []) as AlertRow[];
    const pending = rows.filter((row) => toDateValue(row.last_notified_at) < toDateValue(row.last_seen_at));

    if (pending.length === 0) {
      return new Response(
        JSON.stringify({ message: "No new alerts to notify", source, pending: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!webhookUrl) {
      return new Response(
        JSON.stringify({
          message: "INGESTION_ALERT_WEBHOOK_URL is not set; alerts left pending",
          source,
          pending: pending.length,
          alert_ids: pending.map((row) => row.id),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const payload = buildPayload(webhookUrl, source, pending);
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const bodyText = await response.text();
      throw new Error(`Webhook notify failed (${response.status}): ${bodyText}`);
    }

    const nowIso = new Date().toISOString();
    const ids = pending.map((row) => row.id);

    const { error: updateError } = await supabase
      .from("ingestion_alert_events")
      .update({ last_notified_at: nowIso })
      .in("id", ids);

    if (updateError) {
      throw new Error(`Failed to mark alerts notified: ${updateError.message}`);
    }

    return new Response(
      JSON.stringify({
        message: "Alerts sent",
        source,
        notified: ids.length,
        alert_ids: ids,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
