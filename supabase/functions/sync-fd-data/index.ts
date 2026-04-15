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

function asObject(value: unknown): Json {
  if (value && typeof value === "object") {
    return value as Json;
  }
  return {};
}

function extractId(value: unknown): string | null {
  if (typeof value === "string" || typeof value === "number") {
    return String(value);
  }

  if (value && typeof value === "object") {
    const obj = value as Json;
    const id = obj.id;
    if (typeof id === "string" || typeof id === "number") {
      return String(id);
    }
  }

  return null;
}

function calculateFantasyPoints(params: {
  position: string | null;
  goals: number;
  assists: number;
  cleanSheet: boolean;
  yellowCards: number;
  redCards: number;
  saves: number;
  bonus: number;
}): number {
  const position = normalizePosition(params.position);

  const goalPoints =
    position === "goalkeeper"
      ? params.goals * 10
      : position === "defender"
      ? params.goals * 6
      : position === "forward"
      ? params.goals * 4
      : params.goals * 5;

  const cleanSheetPoints =
    params.cleanSheet && (position === "goalkeeper" || position === "defender")
      ? 4
      : 0;

  return (
    goalPoints +
    (params.assists * 3) +
    cleanSheetPoints +
    params.bonus -
    params.yellowCards -
    (params.redCards * 3) +
    Math.floor(params.saves / 3)
  );
}

type PlayerMatchStats = {
  playerId: number;
  fixtureId: number;
  teamId: number | null;
  season: string;
  gameweek: number;
  minutes: number;
  goals: number;
  assists: number;
  cleanSheet: boolean;
  yellowCards: number;
  redCards: number;
  saves: number;
  bonus: number;
};

type FixtureEventPayload = {
  fixture_id: number;
  provider: string;
  external_id: string;
  event_type: string;
  minute: number | null;
  team_id: number | null;
  player_id: number | null;
  related_player_id: number | null;
  description: string | null;
  raw_event: Json;
  created_at: string;
};

type TeamFormPayload = {
  team_id: number;
  competition_id: number;
  season: string;
  gameweek: number;
  matches_played: number;
  wins: number;
  draws: number;
  losses: number;
  goals_for: number;
  goals_against: number;
  form_points: number;
  expected_goals_for: number;
  expected_goals_against: number;
  raw_stats: Json;
  updated_at: string;
};

function statsKey(playerId: number, fixtureId: number): string {
  return `${playerId}:${fixtureId}`;
}

type PlayerIdentity = {
  id: number;
  position: string | null;
};

function positionBucket(position: string | null): "goalkeeper" | "defender" | "midfielder" | "forward" {
  const normalized = normalizePosition(position);
  if (normalized === "goalkeeper") return "goalkeeper";
  if (normalized === "defender") return "defender";
  if (normalized === "forward") return "forward";
  return "midfielder";
}

function pickStarterIds(players: PlayerIdentity[]): number[] {
  const goalkeepers = players.filter((p) => positionBucket(p.position) === "goalkeeper");
  const defenders = players.filter((p) => positionBucket(p.position) === "defender");
  const midfielders = players.filter((p) => positionBucket(p.position) === "midfielder");
  const forwards = players.filter((p) => positionBucket(p.position) === "forward");

  const selected = new Set<number>();

  function take(from: PlayerIdentity[], count: number): void {
    from
      .slice()
      .sort((a, b) => a.id - b.id)
      .slice(0, count)
      .forEach((p) => selected.add(p.id));
  }

  take(goalkeepers, 1);
  take(defenders, 4);
  take(midfielders, 4);
  take(forwards, 2);

  if (selected.size < 11) {
    const ordered = players.slice().sort((a, b) => a.id - b.id);
    for (const player of ordered) {
      selected.add(player.id);
      if (selected.size >= 11) break;
    }
  }

  return Array.from(selected);
}

async function fetchFootballData(path: string, token: string): Promise<Json> {
  const maxAttempts = 4;
  let lastError = "Unknown error";

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const response = await fetch(`${FOOTBALL_DATA_BASE}${path}`, {
      headers: {
        "X-Auth-Token": token,
        "X-Unfold-Goals": "true",
      },
    });

    if (response.ok) {
      return (await response.json()) as Json;
    }

    const text = await response.text();
    lastError = `football-data ${response.status}: ${text}`;

    // football-data free tier frequently returns 429 with "Wait 30 seconds".
    if (response.status === 429 && attempt < maxAttempts) {
      await new Promise((resolve) => setTimeout(resolve, 32000));
      continue;
    }

    if (response.status >= 500 && attempt < maxAttempts) {
      await new Promise((resolve) => setTimeout(resolve, 2000 * attempt));
      continue;
    }

    throw new Error(lastError);
  }

  throw new Error(lastError);
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

    // 4) Player gameweek points from match events (goals/assists/cards)
    const { data: fixtureMapRows, error: fixtureMapError } = await supabase
      .from("fd_fixtures")
      .select("id, external_id, gameweek, home_team_id, away_team_id, home_score, away_score, status")
      .eq("provider", "football-data")
      .eq("competition_id", competitionId)
      .eq("season", seasonLabel);

    if (fixtureMapError || !fixtureMapRows) {
      throw new Error(`Fixture map load failed: ${fixtureMapError?.message ?? "unknown"}`);
    }

    const fixtureByExternalId = new Map<string, {
      id: number;
      gameweek: number;
      homeTeamId: number;
      awayTeamId: number;
      homeScore: number | null;
      awayScore: number | null;
      status: string;
    }>();
    for (const row of fixtureMapRows as Array<{
      id: number;
      external_id: string;
      gameweek: number;
      home_team_id: number;
      away_team_id: number;
      home_score: number | null;
      away_score: number | null;
      status: string;
    }>) {
      fixtureByExternalId.set(String(row.external_id), {
        id: row.id,
        gameweek: typeof row.gameweek === "number" ? row.gameweek : 0,
        homeTeamId: row.home_team_id,
        awayTeamId: row.away_team_id,
        homeScore: typeof row.home_score === "number" ? row.home_score : null,
        awayScore: typeof row.away_score === "number" ? row.away_score : null,
        status: typeof row.status === "string" ? row.status : "SCHEDULED",
      });
    }

    const { data: playerMapRows, error: playerMapError } = await supabase
      .from("fd_players")
      .select("id, external_id, position, team_id")
      .eq("provider", "football-data")
      .eq("is_active", true);

    if (playerMapError || !playerMapRows) {
      throw new Error(`Player map load failed: ${playerMapError?.message ?? "unknown"}`);
    }

    const playerByExternalId = new Map<string, { id: number; position: string | null }>();
    const playerPositionById = new Map<number, string | null>();
    const playerTeamIdById = new Map<number, number | null>();
    const playersByTeamId = new Map<number, PlayerIdentity[]>();
    for (const row of playerMapRows as Array<{ id: number; external_id: string; position: string | null; team_id: number }>) {
      playerByExternalId.set(String(row.external_id), {
        id: row.id,
        position: row.position,
      });
      playerPositionById.set(row.id, row.position);
      playerTeamIdById.set(row.id, row.team_id ?? null);

      const list = playersByTeamId.get(row.team_id) ?? [];
      list.push({ id: row.id, position: row.position });
      playersByTeamId.set(row.team_id, list);
    }

    const statsByPlayerFixture = new Map<string, PlayerMatchStats>();
    const fixtureEvents: FixtureEventPayload[] = [];
    let parsedGoalEvents = 0;
    let parsedAssistEvents = 0;
    let parsedCardEvents = 0;
    let upsertedFixtureEvents = 0;

    function ensureStats(playerId: number, fixtureId: number, gameweek: number): PlayerMatchStats {
      const key = statsKey(playerId, fixtureId);
      const existing = statsByPlayerFixture.get(key);
      if (existing) return existing;

      const created: PlayerMatchStats = {
        playerId,
        fixtureId,
        teamId: playerTeamIdById.get(playerId) ?? null,
        season: seasonLabel,
        gameweek,
        minutes: 0,
        goals: 0,
        assists: 0,
        cleanSheet: false,
        yellowCards: 0,
        redCards: 0,
        saves: 0,
        bonus: 0,
      };
      statsByPlayerFixture.set(key, created);
      return created;
    }

    for (const match of matches) {
      const matchId = String(match.id ?? "");
      const fixture = fixtureByExternalId.get(matchId);
      if (!fixture) continue;

      const gameweek = typeof match.matchday === "number" ? match.matchday : fixture.gameweek;

      const goals = Array.isArray(match.goals) ? (match.goals as unknown[]) : [];
      for (const rawGoal of goals) {
        const goal = asObject(rawGoal);
        const minute = typeof goal.minute === 'number' ? goal.minute : null;

        const ownGoal = Boolean(goal.ownGoal);
        const scorerExternalId =
          extractId(goal.scorer) ??
          extractId(goal.player) ??
          extractId(goal.scorerId) ??
          extractId(goal.playerId);

        if (!ownGoal && scorerExternalId) {
          const scorer = playerByExternalId.get(scorerExternalId);
          if (scorer) {
            const stats = ensureStats(scorer.id, fixture.id, gameweek);
            stats.goals += 1;
            parsedGoalEvents += 1;
            fixtureEvents.push({
              fixture_id: fixture.id,
              provider: 'football-data',
              external_id: `${matchId}:goal:${parsedGoalEvents}`,
              event_type: 'goal',
              minute,
              team_id: playerTeamIdById.get(scorer.id) ?? null,
              player_id: scorer.id,
              related_player_id: null,
              description: 'Goal',
              raw_event: goal,
              created_at: new Date().toISOString(),
            });
          }
        }

        const assistExternalId =
          extractId(goal.assist) ??
          extractId(goal.assistId) ??
          extractId(goal.assistedBy);

        if (assistExternalId) {
          const assister = playerByExternalId.get(assistExternalId);
          if (assister) {
            const stats = ensureStats(assister.id, fixture.id, gameweek);
            stats.assists += 1;
            parsedAssistEvents += 1;
            fixtureEvents.push({
              fixture_id: fixture.id,
              provider: 'football-data',
              external_id: `${matchId}:assist:${parsedAssistEvents}`,
              event_type: 'assist',
              minute,
              team_id: playerTeamIdById.get(assister.id) ?? null,
              player_id: assister.id,
              related_player_id: scorerExternalId ? (playerByExternalId.get(scorerExternalId)?.id ?? null) : null,
              description: 'Assist',
              raw_event: goal,
              created_at: new Date().toISOString(),
            });
          }
        }
      }

      const bookings = Array.isArray(match.bookings) ? (match.bookings as unknown[]) : [];
      for (const rawBooking of bookings) {
        const booking = asObject(rawBooking);
        const playerExternalId =
          extractId(booking.player) ??
          extractId(booking.person) ??
          extractId(booking.playerId);
        if (!playerExternalId) continue;

        const player = playerByExternalId.get(playerExternalId);
        if (!player) continue;

        const stats = ensureStats(player.id, fixture.id, gameweek);
        const cardType = String(booking.card ?? booking.cardType ?? "").toLowerCase();

        if (cardType.includes("red")) {
          stats.redCards += 1;
          parsedCardEvents += 1;
          fixtureEvents.push({
            fixture_id: fixture.id,
            provider: 'football-data',
            external_id: `${matchId}:card:${parsedCardEvents}:red`,
            event_type: 'red_card',
            minute: typeof booking.minute === 'number' ? booking.minute : null,
            team_id: playerTeamIdById.get(player.id) ?? null,
            player_id: player.id,
            related_player_id: null,
            description: 'Red card',
            raw_event: booking,
            created_at: new Date().toISOString(),
          });
        } else if (cardType.includes("yellow")) {
          stats.yellowCards += 1;
          parsedCardEvents += 1;
          fixtureEvents.push({
            fixture_id: fixture.id,
            provider: 'football-data',
            external_id: `${matchId}:card:${parsedCardEvents}:yellow`,
            event_type: 'yellow_card',
            minute: typeof booking.minute === 'number' ? booking.minute : null,
            team_id: playerTeamIdById.get(player.id) ?? null,
            player_id: player.id,
            related_player_id: null,
            description: 'Yellow card',
            raw_event: booking,
            created_at: new Date().toISOString(),
          });
        }
      }
    }

    if (fixtureEvents.length > 0) {
      for (const chunk of chunkArray(fixtureEvents, 300)) {
        const { error: eventsError } = await supabase
          .from('fd_fixture_events')
          .upsert(chunk, { onConflict: 'provider,external_id' });
        if (eventsError) {
          throw new Error(`Fixture events upsert failed: ${eventsError.message}`);
        }
        upsertedFixtureEvents += chunk.length;
      }
    }

    // Fallback mode: if player-level event feed is missing, estimate starter points from team results.
    let fallbackStarterRows = 0;
    for (const fixture of fixtureByExternalId.values()) {
      if (fixture.homeScore == null || fixture.awayScore == null) continue;
      if (fixture.status.toUpperCase() !== "FINISHED") continue;

      const homePlayers = playersByTeamId.get(fixture.homeTeamId) ?? [];
      const awayPlayers = playersByTeamId.get(fixture.awayTeamId) ?? [];
      if (homePlayers.length === 0 && awayPlayers.length === 0) continue;

      const homeStarterIds = pickStarterIds(homePlayers);
      const awayStarterIds = pickStarterIds(awayPlayers);

      const homeResultBonus = fixture.homeScore > fixture.awayScore ? 1 : (fixture.homeScore < fixture.awayScore ? -1 : 0);
      const awayResultBonus = fixture.awayScore > fixture.homeScore ? 1 : (fixture.awayScore < fixture.homeScore ? -1 : 0);

      for (const playerId of homeStarterIds) {
        const stats = ensureStats(playerId, fixture.id, fixture.gameweek);
        stats.minutes = Math.max(stats.minutes, 90);
        stats.bonus += 2 + homeResultBonus; // appearance + team result
        const position = playerPositionById.get(playerId) ?? null;
        const bucket = positionBucket(position);
        if (fixture.awayScore === 0 && (bucket === "goalkeeper" || bucket === "defender")) {
          stats.cleanSheet = true;
        }
        fallbackStarterRows += 1;
      }

      for (const playerId of awayStarterIds) {
        const stats = ensureStats(playerId, fixture.id, fixture.gameweek);
        stats.minutes = Math.max(stats.minutes, 90);
        stats.bonus += 2 + awayResultBonus; // appearance + team result
        const position = playerPositionById.get(playerId) ?? null;
        const bucket = positionBucket(position);
        if (fixture.homeScore === 0 && (bucket === "goalkeeper" || bucket === "defender")) {
          stats.cleanSheet = true;
        }
        fallbackStarterRows += 1;
      }
    }

    const playerGameweekPayload = Array.from(statsByPlayerFixture.values()).map((stats) => {
      const points = calculateFantasyPoints({
        position: playerPositionById.get(stats.playerId) ?? null,
        goals: stats.goals,
        assists: stats.assists,
        cleanSheet: stats.cleanSheet,
        yellowCards: stats.yellowCards,
        redCards: stats.redCards,
        saves: stats.saves,
        bonus: stats.bonus,
      });

      return {
        player_id: stats.playerId,
        season: stats.season,
        gameweek: stats.gameweek,
        fixture_id: stats.fixtureId,
        team_id: stats.teamId,
        minutes: stats.minutes,
        goals: stats.goals,
        assists: stats.assists,
        expected_goals: 0,
        expected_assists: 0,
        clean_sheet: stats.cleanSheet,
        yellow_cards: stats.yellowCards,
        red_cards: stats.redCards,
        saves: stats.saves,
        bonus: stats.bonus,
        points,
        source: "football-data-events",
        raw_stats: {
          source: 'football-data',
          goals: stats.goals,
          assists: stats.assists,
          yellowCards: stats.yellowCards,
          redCards: stats.redCards,
          cleanSheet: stats.cleanSheet,
          bonus: stats.bonus,
        },
        updated_at: new Date().toISOString(),
      };
    });

    let playerGameweekUpserts = 0;
    for (const chunk of chunkArray(playerGameweekPayload, 300)) {
      const { error: pointsError } = await supabase
        .from("fd_player_gameweek_points")
        .upsert(chunk, { onConflict: "player_id,season,gameweek,fixture_id" });
      if (pointsError) {
        throw new Error(`Player gameweek points upsert failed: ${pointsError.message}`);
      }
      playerGameweekUpserts += chunk.length;
    }

    const teamFormByTeamAndGw = new Map<string, TeamFormPayload>();
    for (const match of matches) {
      const homeTeam = (match.homeTeam ?? {}) as Json;
      const awayTeam = (match.awayTeam ?? {}) as Json;
      const score = (match.score ?? {}) as Json;
      const fullTime = (score.fullTime ?? {}) as Json;
      const homeExternal = String(homeTeam.id ?? "");
      const awayExternal = String(awayTeam.id ?? "");
      const homeId = teamIdByExternal.get(homeExternal);
      const awayId = teamIdByExternal.get(awayExternal);
      const homeGoals = typeof fullTime.home === 'number' ? fullTime.home : null;
      const awayGoals = typeof fullTime.away === 'number' ? fullTime.away : null;
      if (!homeId || !awayId || homeGoals == null || awayGoals == null) continue;

      const matchday = typeof match.matchday === 'number' ? match.matchday : 0;
      const gameweek = matchday;
      const homeWon = homeGoals > awayGoals;
      const awayWon = awayGoals > homeGoals;
      const homeKey = `${homeId}:${gameweek}`;
      const awayKey = `${awayId}:${gameweek}`;

      const homeEntry = teamFormByTeamAndGw.get(homeKey) ?? {
        team_id: homeId,
        competition_id: competitionId,
        season: seasonLabel,
        gameweek,
        matches_played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goals_for: 0,
        goals_against: 0,
        form_points: 0,
        expected_goals_for: 0,
        expected_goals_against: 0,
        raw_stats: { source: 'football-data', team: 'home' },
        updated_at: new Date().toISOString(),
      };
      homeEntry.matches_played += 1;
      homeEntry.goals_for += homeGoals;
      homeEntry.goals_against += awayGoals;
      homeEntry.form_points += homeWon ? 3 : (homeGoals === awayGoals ? 1 : 0);
      homeEntry.wins += homeWon ? 1 : 0;
      homeEntry.draws += homeGoals === awayGoals ? 1 : 0;
      homeEntry.losses += awayWon ? 1 : 0;
      teamFormByTeamAndGw.set(homeKey, homeEntry);

      const awayEntry = teamFormByTeamAndGw.get(awayKey) ?? {
        team_id: awayId,
        competition_id: competitionId,
        season: seasonLabel,
        gameweek,
        matches_played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goals_for: 0,
        goals_against: 0,
        form_points: 0,
        expected_goals_for: 0,
        expected_goals_against: 0,
        raw_stats: { source: 'football-data', team: 'away' },
        updated_at: new Date().toISOString(),
      };
      awayEntry.matches_played += 1;
      awayEntry.goals_for += awayGoals;
      awayEntry.goals_against += homeGoals;
      awayEntry.form_points += awayWon ? 3 : (homeGoals === awayGoals ? 1 : 0);
      awayEntry.wins += awayWon ? 1 : 0;
      awayEntry.draws += homeGoals === awayGoals ? 1 : 0;
      awayEntry.losses += homeWon ? 1 : 0;
      teamFormByTeamAndGw.set(awayKey, awayEntry);
    }

    if (teamFormByTeamAndGw.size > 0) {
      const teamFormPayload = Array.from(teamFormByTeamAndGw.values());
      for (const chunk of chunkArray(teamFormPayload, 300)) {
        const { error: formError } = await supabase
          .from('fd_team_form')
          .upsert(chunk, { onConflict: 'team_id,season,gameweek' });
        if (formError) {
          throw new Error(`Team form upsert failed: ${formError.message}`);
        }
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        season,
        competitionExternalId,
        upsertedTeams: teamPayload.length,
        upsertedFixtures: fixturePayload.length,
        upsertedPlayers: playerUpserts,
        upsertedPlayerGameweekPoints: playerGameweekUpserts,
        upsertedFixtureEvents,
        upsertedTeamFormRows: teamFormByTeamAndGw.size,
        parsedGoalEvents,
        parsedAssistEvents,
        parsedCardEvents,
        fallbackStarterRows,
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
