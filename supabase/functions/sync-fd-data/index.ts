import { createClient } from "npm:@supabase/supabase-js@2";

type Json = Record<string, unknown>;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-ingestion-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const FOOTBALL_DATA_BASE = "https://api.football-data.org/v4";

function toSeasonLabel(season: number): string {
  return `${season}/${season + 1}`;
}

function chunkArray<T>(items: T[], size: number): T[][] {
  if (items.length == 0) return [];
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

function normalizePosition(rawPosition: string | null | undefined): string | null {
  const value = (rawPosition ?? '').toLowerCase();
  if (value.includes('goal') || value === 'gk') return 'goalkeeper';
  if (value.includes('back') || value.includes('def') || value === 'cb' || value === 'lb' || value === 'rb') return 'defender';
  if (value.includes('mid') || value === 'cm' || value === 'am' || value === 'lm' || value === 'rm') return 'midfielder';
  if (value.includes('forw') || value.includes('strik') || value === 'st' || value === 'cf') return 'forward';
  return value || null;
}

function estimatePrice(position: string | null): number {
  switch (position) {
    case 'goalkeeper':
      return 5.0;
    case 'defender':
      return 5.5;
    case 'midfielder':
      return 6.5;
    case 'forward':
      return 7.5;
    default:
      return 5.0;
  }
}

async function fetchFootballData(path: string, token: string): Promise<Json> {
  const response = await fetch(`${FOOTBALL_DATA_BASE}${path}`, {
    headers: {
      "X-Auth-Token": token,
      "X-Unfold-Goals": "true",
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`football-data ${response.status}: ${text}`);
  }

  return (await response.json()) as Json;
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
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const footballDataToken = Deno.env.get("FOOTBALL_DATA_API_TOKEN");
    const ingestionSecret = Deno.env.get("INGESTION_SHARED_SECRET");

    if (!supabaseUrl || !serviceRoleKey || !footballDataToken) {
      return new Response(JSON.stringify({ error: "Missing required env vars" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Optional hardening: if secret is configured, require it.
    if (ingestionSecret) {
      const provided = req.headers.get("x-ingestion-secret");
      if (provided != ingestionSecret) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const body = (await req.json().catch(() => ({}))) as {
      season?: number;
      competitionExternalId?: string;
    };

    const season = typeof body.season === "number" ? body.season : 2025;
    const competitionExternalId =
      typeof body.competitionExternalId === "string" ? body.competitionExternalId : "2021";

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // 1) Teams + Competition
    const teamsData = await fetchFootballData(
      `/competitions/${competitionExternalId}/teams?season=${season}`,
      footballDataToken,
    );

    const competition = (teamsData.competition ?? {}) as Json;
    const area = (competition.area ?? {}) as Json;

    const { data: competitionRows, error: competitionError } = await supabase
      .from("fd_competitions")
      .upsert(
        {
          provider: "football-data",
          external_id: String(competition.external_id ?? competition.id ?? competitionExternalId),
          code: typeof competition.code === "string" ? competition.code : null,
          name: typeof competition.name === "string" ? competition.name : "Premier League",
          country: typeof area.name === "string" ? area.name : null,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "provider,external_id" },
      )
      .select("id")
      .limit(1);

    if (competitionError || !competitionRows || competitionRows.length == 0) {
      throw new Error(`Competition upsert failed: ${competitionError?.message ?? "no row"}`);
    }

    const competitionId = competitionRows[0].id as number;

    const teamRows = Array.isArray(teamsData.teams) ? (teamsData.teams as Json[]) : [];

    const teamPayload = teamRows.map((t) => ({
      provider: "football-data",
      external_id: String(t.id),
      name: typeof t.name === "string" ? t.name : "Unknown Team",
      short_name: typeof t.shortName === "string" ? t.shortName : null,
      tla: typeof t.tla === "string" ? t.tla : null,
      crest_url: typeof t.crest === "string" ? t.crest : null,
      competition_id: competitionId,
      updated_at: new Date().toISOString(),
    }));

    if (teamPayload.length > 0) {
      const { error: teamsError } = await supabase
        .from("fd_teams")
        .upsert(teamPayload, { onConflict: "provider,external_id" });
      if (teamsError) {
        throw new Error(`Teams upsert failed: ${teamsError.message}`);
      }
    }

    const { data: teamMapRows, error: teamMapError } = await supabase
      .from("fd_teams")
      .select("id, external_id")
      .eq("provider", "football-data")
      .eq("competition_id", competitionId);

    if (teamMapError || !teamMapRows) {
      throw new Error(`Team map load failed: ${teamMapError?.message ?? "unknown"}`);
    }

    const teamIdByExternal = new Map<string, number>();
    for (const row of teamMapRows as Array<{ id: number; external_id: string }>) {
      teamIdByExternal.set(String(row.external_id), row.id);
    }

    // 2) Fixtures
    const matchesData = await fetchFootballData(
      `/competitions/${competitionExternalId}/matches?season=${season}`,
      footballDataToken,
    );

    const matches = Array.isArray(matchesData.matches) ? (matchesData.matches as Json[]) : [];
    const seasonLabel = toSeasonLabel(season);

    const fixturePayload = matches
      .map((m) => {
        const homeTeam = (m.homeTeam ?? {}) as Json;
        const awayTeam = (m.awayTeam ?? {}) as Json;
        const score = (m.score ?? {}) as Json;
        const fullTime = (score.fullTime ?? {}) as Json;

        const homeExternal = String(homeTeam.id ?? "");
        const awayExternal = String(awayTeam.id ?? "");
        const homeId = teamIdByExternal.get(homeExternal);
        const awayId = teamIdByExternal.get(awayExternal);

        if (!homeId || !awayId) {
          return null;
        }

        return {
          provider: "football-data",
          external_id: String(m.id),
          competition_id: competitionId,
          season: seasonLabel,
          gameweek: typeof m.matchday === "number" ? m.matchday : 0,
          utc_kickoff:
            typeof m.utcDate === "string"
              ? m.utcDate
              : new Date().toISOString(),
          status: typeof m.status === "string" ? m.status : "SCHEDULED",
          home_team_id: homeId,
          away_team_id: awayId,
          home_score: typeof fullTime.home === "number" ? fullTime.home : null,
          away_score: typeof fullTime.away === "number" ? fullTime.away : null,
          updated_at: new Date().toISOString(),
        };
      })
      .filter((x) => x !== null);

    for (const chunk of chunkArray(fixturePayload, 300)) {
      const { error: fixturesError } = await supabase
        .from("fd_fixtures")
        .upsert(chunk, { onConflict: "provider,external_id" });
      if (fixturesError) {
        throw new Error(`Fixtures upsert failed: ${fixturesError.message}`);
      }
    }

    // 3) Players from each team squad
    let playerUpserts = 0;

    const { error: resetPlayersError } = await supabase
      .from("fd_players")
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq("provider", "football-data");

    if (resetPlayersError) {
      throw new Error(`Player reset failed: ${resetPlayersError.message}`);
    }

    const teamsForSquads = teamRows.map((t) => String(t.id));

    for (const teamExternalId of teamsForSquads) {
      const teamInternalId = teamIdByExternal.get(teamExternalId);
      if (!teamInternalId) continue;

      const teamData = await fetchFootballData(`/teams/${teamExternalId}`, footballDataToken);
      const squad = Array.isArray(teamData.squad) ? (teamData.squad as Json[]) : [];

      if (squad.length == 0) continue;

      const playerPayload = squad.map((p) => ({
        provider: "football-data",
        external_id: String(p.id),
        team_id: teamInternalId,
        name: typeof p.name === "string" ? p.name : "Unknown Player",
        position: normalizePosition(typeof p.position === "string" ? p.position : null),
        nationality: typeof p.nationality === "string" ? p.nationality : null,
        price: estimatePrice(normalizePosition(typeof p.position === "string" ? p.position : null)),
        last_seen_at: new Date().toISOString(),
        is_active: true,
        updated_at: new Date().toISOString(),
      }));

      for (const chunk of chunkArray(playerPayload, 300)) {
        const { error: playersError } = await supabase
          .from("fd_players")
          .upsert(chunk, { onConflict: "provider,external_id" });
        if (playersError) {
          throw new Error(`Players upsert failed (team ${teamExternalId}): ${playersError.message}`);
        }
      }

      playerUpserts += playerPayload.length;
    }

    return new Response(
      JSON.stringify({
        ok: true,
        season,
        competitionExternalId,
        upsertedTeams: teamPayload.length,
        upsertedFixtures: fixturePayload.length,
        upsertedPlayers: playerUpserts,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
