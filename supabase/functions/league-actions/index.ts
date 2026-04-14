// @ts-ignore Deno/Supabase Edge Functions resolve this via the function import map at deploy time.
import { createClient } from "npm:@supabase/supabase-js@2";

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

type Json = Record<string, unknown>;
type LeagueRow = Record<string, unknown>;
type MemberRow = {
  user_id: string;
  joined_at?: string;
  fantasy_leagues?: LeagueRow;
};
type TeamRow = Record<string, unknown>;
type StandingRow = {
  userId: string;
  userName: string;
  teamName: string;
  rank: number;
  totalPoints: number;
  gameweekPoints: number;
  joinedAt?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Json, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function asString(value: unknown, fallback = "") {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

function asInt(value: unknown, fallback = 0) {
  return typeof value === "number" && Number.isFinite(value) ? Math.trunc(value) : fallback;
}

function requiredUserId(body: Json): string {
  const userId = asString(body.userId ?? body.firebaseUid, "");
  if (!userId || userId === "guest") {
    throw new Error("Authenticated userId is required");
  }
  return userId;
}

function makeLeagueCode(length = 6) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < length; i += 1) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

async function upsertTeamSnapshot(supabase: ReturnType<typeof createClient>, body: Json) {
  const userId = requiredUserId(body);
  const teamName = asString(body.teamName, "My Team");
  const userName = asString(body.userName ?? body.displayName ?? body.email, "");

  const payload = {
    user_id: userId,
    user_name: userName || null,
    team_name: teamName,
    total_points: asInt(body.totalPoints),
    gameweek_points: asInt(body.gameweekPoints),
    remaining_budget: typeof body.remainingBudget === "number" ? body.remainingBudget : 0,
    updated_at: new Date().toISOString(),
  };

  const { error } = await supabase
    .from("fantasy_teams")
    .upsert(payload, { onConflict: "user_id" });

  if (error) {
    throw new Error(`Team snapshot sync failed: ${error.message}`);
  }

  return payload;
}

async function recalcLeagueMembersCount(supabase: ReturnType<typeof createClient>, leagueId: string) {
  const { count, error } = await supabase
    .from("fantasy_league_members")
    .select("id", { count: "exact", head: true })
    .eq("league_id", leagueId);

  if (error) {
    throw new Error(`Failed to count league members: ${error.message}`);
  }

  const { error: updateError } = await supabase
    .from("fantasy_leagues")
    .update({ members_count: count ?? 0, updated_at: new Date().toISOString() })
    .eq("id", leagueId);

  if (updateError) {
    throw new Error(`Failed to update league count: ${updateError.message}`);
  }
}

async function createLeague(supabase: ReturnType<typeof createClient>, body: Json) {
  const name = asString(body.name, "Untitled League");
  const type = asString(body.type, "public");
  const userId = requiredUserId(body);
  const userName = asString(body.userName ?? body.displayName ?? body.email, "");
  const teamSnapshot = await upsertTeamSnapshot(supabase, body);

  const leaguePayload = {
    name,
    code: type === "private" ? makeLeagueCode() : null,
    type: type === "private" ? "private" : "public",
    created_by_user_id: userId,
    created_by_name: userName || null,
    members_count: 0,
    updated_at: new Date().toISOString(),
  };

  const { data: leagueRows, error } = await supabase
    .from("fantasy_leagues")
    .insert(leaguePayload)
    .select("id, name, code, type, created_by_user_id, created_by_name, members_count, created_at")
    .limit(1);

  if (error || !leagueRows || leagueRows.length === 0) {
    throw new Error(`League creation failed: ${error?.message ?? "no row returned"}`);
  }

  const league = leagueRows[0] as LeagueRow;
  const leagueId = asString(league.id);

  const { error: memberError } = await supabase
    .from("fantasy_league_members")
    .upsert({ league_id: leagueId, user_id: userId }, { onConflict: "league_id,user_id" });

  if (memberError) {
    throw new Error(`League member insert failed: ${memberError.message}`);
  }

  await recalcLeagueMembersCount(supabase, leagueId);

  return {
    ...league,
    membersCount: 1,
    createdBy: league.created_by_user_id ?? userId,
    teamSnapshot,
  };
}

async function joinLeague(supabase: ReturnType<typeof createClient>, body: Json) {
  const userId = requiredUserId(body);
  const teamSnapshot = await upsertTeamSnapshot(supabase, body);
  const leagueId = asString(body.leagueId);
  const leagueCode = asString(body.leagueCode);

  let query = supabase.from("fantasy_leagues").select("id, name, code, type, created_by_user_id, created_by_name, members_count, created_at");

  if (leagueId) {
    query = query.eq("id", leagueId);
  } else if (leagueCode) {
    query = query.eq("code", leagueCode);
  } else {
    throw new Error("leagueId or leagueCode is required");
  }

  const { data: leagueRows, error } = await query.limit(1);
  if (error || !leagueRows || leagueRows.length === 0) {
    throw new Error(`League not found: ${error?.message ?? leagueCode ?? leagueId}`);
  }

  const league = leagueRows[0] as Record<string, unknown>;
  const resolvedLeagueId = asString(league.id);

  const { error: memberError } = await supabase
    .from("fantasy_league_members")
    .upsert({ league_id: resolvedLeagueId, user_id: userId }, { onConflict: "league_id,user_id" });

  if (memberError) {
    throw new Error(`Failed to join league: ${memberError.message}`);
  }

  await recalcLeagueMembersCount(supabase, resolvedLeagueId);

  return { ...league, teamSnapshot };
}

async function myLeagues(supabase: ReturnType<typeof createClient>, body: Json) {
  const userId = requiredUserId(body);
  const { data: rows, error } = await supabase
    .from("fantasy_league_members")
    .select("league_id, fantasy_leagues(id, name, code, type, created_by_user_id, created_by_name, members_count, created_at)")
    .eq("user_id", userId)
    .order("joined_at", { ascending: false });

  if (error) {
    throw new Error(`Failed to load leagues: ${error.message}`);
  }

  return (rows ?? [])
    .map((row: MemberRow) => row.fantasy_leagues as LeagueRow | undefined)
    .filter((league: LeagueRow | undefined): league is LeagueRow => !!league)
    .map((league: LeagueRow) => ({
      ...league,
      createdBy: league.created_by_user_id,
      membersCount: league.members_count,
    }));
}

async function publicLeagues(supabase: ReturnType<typeof createClient>) {
  const { data, error } = await supabase
    .from("fantasy_leagues")
    .select("id, name, code, type, created_by_user_id, created_by_name, members_count, created_at")
    .eq("type", "public")
    .order("members_count", { ascending: false })
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(`Failed to load public leagues: ${error.message}`);
  }

  return (data ?? []).map((league: LeagueRow) => ({
    ...league,
    createdBy: (league as Record<string, unknown>).created_by_user_id,
    membersCount: (league as Record<string, unknown>).members_count,
  }));
}

async function leagueStandings(supabase: ReturnType<typeof createClient>, body: Json) {
  const leagueId = asString(body.leagueId);
  if (!leagueId) {
    throw new Error("leagueId is required");
  }

  const { data: members, error: memberError } = await supabase
    .from("fantasy_league_members")
    .select("user_id, joined_at")
    .eq("league_id", leagueId)
    .order("joined_at", { ascending: true });

  if (memberError) {
    throw new Error(`Failed to load standings: ${memberError.message}`);
  }

  const memberRows = (members ?? []) as MemberRow[];
  const userIds = memberRows.map((row: MemberRow) => asString(row.user_id));
  const { data: teams, error: teamsError } = await supabase
    .from("fantasy_teams")
    .select("user_id, user_name, team_name, total_points, gameweek_points, updated_at")
    .in("user_id", userIds);

  if (teamsError) {
    throw new Error(`Failed to load team snapshots: ${teamsError.message}`);
  }

  const teamByUserId = new Map<string, TeamRow>();
  for (const team of teams ?? []) {
    const row = team as TeamRow;
    teamByUserId.set(asString(row.user_id), row);
  }

  const standings = userIds
    .map((userId: string, index: number): StandingRow => {
      const team = teamByUserId.get(userId) ?? {};
      return {
        userId,
        userName: asString(team.user_name, `Player ${index + 1}`),
        teamName: asString(team.team_name, 'My Team'),
        rank: 0,
        totalPoints: asInt(team.total_points),
        gameweekPoints: asInt(team.gameweek_points),
        joinedAt: memberRows[index]?.joined_at,
      };
    })
    .sort((a: StandingRow, b: StandingRow) => {
      if (b.totalPoints !== a.totalPoints) return b.totalPoints - a.totalPoints;
      if (b.gameweekPoints !== a.gameweekPoints) return b.gameweekPoints - a.gameweekPoints;
      return String(a.joinedAt ?? '').localeCompare(String(b.joinedAt ?? ''));
    })
    .map((row: StandingRow, index: number) => ({
      userId: row.userId,
      userName: row.userName,
      teamName: row.teamName,
      rank: index + 1,
      totalPoints: row.totalPoints,
      gameweekPoints: row.gameweekPoints,
    }));

  return standings;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: "Missing required env vars" }, 500);
    }

    const body = (await req.json().catch(() => ({}))) as Json;
    const action = asString(body.action);
    if (!action) {
      return jsonResponse({ error: "action is required" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    switch (action) {
      case "syncTeam":
        return jsonResponse({ data: await upsertTeamSnapshot(supabase, body) });
      case "createLeague":
        return jsonResponse({ data: await createLeague(supabase, body) });
      case "joinLeague":
        return jsonResponse({ data: await joinLeague(supabase, body) });
      case "myLeagues":
        return jsonResponse({ data: await myLeagues(supabase, body) });
      case "publicLeagues":
        return jsonResponse({ data: await publicLeagues(supabase) });
      case "standings":
        return jsonResponse({ data: await leagueStandings(supabase, body) });
      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
