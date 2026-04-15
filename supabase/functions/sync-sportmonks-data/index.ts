import { createClient } from "npm:@supabase/supabase-js@2";

type Json = Record<string, unknown>;

type FixtureMapRow = {
  id: number;
  competition_id: number;
  gameweek: number;
  home_team_id: number;
  away_team_id: number;
  home_score: number | null;
  away_score: number | null;
};

const SPORTMONKS_BASE = "https://api.sportmonks.com/v3/football";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-ingestion-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function asObject(value: unknown): Json {
  if (value && typeof value === "object") return value as Json;
  return {};
}

function asList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asString(value: unknown, fallback = ""): string {
  if (typeof value === "string" && value.trim().length > 0) return value.trim();
  if (typeof value === "number") return String(value);
  return fallback;
}

function asInt(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function asNum(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function readNumericFromUnknown(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const cleaned = value.replace(/[^0-9.+-]/g, "");
    if (!cleaned) return null;
    const parsed = Number.parseFloat(cleaned);
    if (Number.isFinite(parsed)) return parsed;
  }
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const priorityKeys = ["value", "amount", "total", "xg", "xa"];
    for (const key of priorityKeys) {
      if (key in obj) {
        const nested = readNumericFromUnknown(obj[key]);
        if (nested !== null) return nested;
      }
    }
  }
  return null;
}

function extractStatValue(detail: Json): number {
  const sources: unknown[] = [
    detail.value,
    detail.amount,
    detail.total,
    detail.data,
    asObject(detail.data).value,
    asObject(detail.data).amount,
    asObject(detail.data).total,
  ];

  for (const source of sources) {
    const numeric = readNumericFromUnknown(source);
    if (numeric !== null) return numeric;
  }
  return 0;
}

function normalizeName(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\b(fc|cf|afc|sc)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeStatKey(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "").trim();
}

function isExpectedGoalsKey(statKey: string): boolean {
  return statKey === "xg" || statKey.includes("expectedgoals") || statKey.includes("goalsexpected");
}

function isExpectedAssistsKey(statKey: string): boolean {
  return statKey === "xa" || statKey.includes("expectedassists") || statKey.includes("assistexpected");
}

function deriveExpectedAssists(params: {
  keyPasses: number;
  bigChancesCreated: number;
  assists: number;
}): number {
  const estimate =
    params.keyPasses * 0.08 +
    params.bigChancesCreated * 0.25;
  const assistFloor = params.assists > 0 ? params.assists * 0.2 : 0;
  const value = Math.max(estimate, assistFloor, 0);
  return Math.round(value * 1000) / 1000;
}

function seasonLabel(season: number): string {
  return `${season}/${season + 1}`;
}

function seasonWindow(season: number): { start: string; end: string } {
  return {
    start: `${season}-07-01`,
    end: `${season + 1}-06-30`,
  };
}

async function fetchSportmonksFixturesForTeams(teamNames: string[], token: string): Promise<Json[]> {
  const fixtures: Json[] = [];
  const seenFixtureIds = new Set<number>();
  const perPage = 50;
  const maxPagesPerTeam = 8;

  for (const teamName of teamNames) {
    if (!teamName) continue;
    const encodedTeam = encodeURIComponent(teamName);

    for (let page = 1; page <= maxPagesPerTeam; page += 1) {
      const response = await fetchSportmonks(
        `/fixtures/search/${encodedTeam}?include=participants;state&page=${page}&per_page=${perPage}`,
        token,
      );

      const rows = asList(response.data).map(asObject);
      for (const row of rows) {
        const fixtureId = asInt(row.id, 0);
        if (fixtureId <= 0 || seenFixtureIds.has(fixtureId)) continue;
        seenFixtureIds.add(fixtureId);
        fixtures.push(row);
      }

      const pagination = asObject(response.pagination);
      const hasMore = Boolean(pagination.has_more);
      if (!hasMore || rows.length < perPage) break;
    }
  }

  return fixtures;
}

function eventType(event: Json): string {
  const type = event.type;
  if (typeof type === "string") return type.toLowerCase();
  const typeMap = asObject(type);
  return asString(typeMap.developer_name || typeMap.name).toLowerCase();
}

function buildSportmonksUrl(path: string, token: string): string {
  return `${SPORTMONKS_BASE}${path}${path.includes("?") ? "&" : "?"}api_token=${token}`;
}

async function fetchSportmonks(path: string, token: string): Promise<Json> {
  const response = await fetch(buildSportmonksUrl(path, token));
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`sportmonks ${response.status}: ${text}`);
  }
  return (await response.json()) as Json;
}

function fantasyPoints(position: string, stats: {
  goals: number;
  assists: number;
  cleanSheet: boolean;
  yellowCards: number;
  redCards: number;
  saves: number;
  bonus: number;
}): number {
  const pos = position.toLowerCase();
  const goalPoints = pos.includes("goal")
    ? stats.goals * 10
    : pos.includes("def")
    ? stats.goals * 6
    : pos.includes("for")
    ? stats.goals * 4
    : stats.goals * 5;

  const cleanSheetPoints =
    stats.cleanSheet && (pos.includes("goal") || pos.includes("def")) ? 4 : 0;

  return (
    goalPoints +
    stats.assists * 3 +
    cleanSheetPoints +
    stats.bonus -
    stats.yellowCards -
    stats.redCards * 3 +
    Math.floor(stats.saves / 3)
  );
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
    const sportmonksToken = Deno.env.get("SPORTMONKS_API_TOKEN");
    const ingestionSecret = Deno.env.get("INGESTION_SHARED_SECRET");

    if (!supabaseUrl || !serviceRoleKey || !sportmonksToken) {
      throw new Error("Missing required env vars");
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

    const body = (await req.json().catch(() => ({}))) as {
      competitionExternalId?: string;
      season?: number;
    };

    const competitionExternalId = asString(body.competitionExternalId, "2021");
    const season = typeof body.season === "number" ? body.season : 2025;
    const currentSeason = seasonLabel(season);

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: compRows, error: compError } = await supabase
      .from("fd_competitions")
      .select("id")
      .eq("provider", "football-data")
      .eq("external_id", competitionExternalId)
      .limit(1);

    if (compError || !compRows || compRows.length === 0) {
      throw new Error(`Competition map not found: ${compError?.message ?? competitionExternalId}`);
    }
    const competitionId = compRows[0].id as number;

    const [{ data: teamsRows, error: teamsError }, { data: playersRows, error: playersError }, { data: fixturesRows, error: fixturesError }] =
      await Promise.all([
        supabase
          .from("fd_teams")
          .select("id,name")
          .eq("provider", "football-data")
          .eq("competition_id", competitionId),
        supabase
          .from("fd_players")
          .select("id,name,position,team_id")
          .eq("provider", "football-data")
          .eq("is_active", true),
        supabase
          .from("fd_fixtures")
          .select("id,competition_id,gameweek,home_team_id,away_team_id,home_score,away_score")
          .eq("provider", "football-data")
          .eq("competition_id", competitionId)
          .eq("season", currentSeason),
      ]);

    if (teamsError || playersError || fixturesError) {
      throw new Error(`Mapping load failed: ${teamsError?.message ?? playersError?.message ?? fixturesError?.message}`);
    }

    const teamNameToId = new Map<string, number>();
    for (const row of (teamsRows ?? []) as Array<{ id: number; name: string }>) {
      teamNameToId.set(normalizeName(row.name), row.id);
    }

    const playerByTeamAndName = new Map<string, { id: number; position: string }>();
    for (const row of (playersRows ?? []) as Array<{ id: number; name: string; position: string | null; team_id: number }>) {
      const key = `${row.team_id}:${normalizeName(row.name)}`;
      playerByTeamAndName.set(key, { id: row.id, position: asString(row.position, "midfielder") });
    }

    const fixtureByTeams = new Map<string, FixtureMapRow>();
    for (const row of (fixturesRows ?? []) as FixtureMapRow[]) {
      fixtureByTeams.set(`${row.home_team_id}:${row.away_team_id}`, row);
    }

    const competitionTeamNames: string[] = ((teamsRows ?? []) as Array<{ name: string }>).map(
      (row: { name: string }) => row.name,
    );

    const { start, end } = seasonWindow(season);
    const sportmonksFixtures = await fetchSportmonksFixturesForTeams(
      competitionTeamNames,
      sportmonksToken,
    );
    const eventPayload: Json[] = [];
    const injuriesPayload: Json[] = [];
    const suspensionsPayload: Json[] = [];
    const playerStatsPayload: Json[] = [];
    const pointsPayload: Json[] = [];
    const teamFormPayload: Json[] = [];

    let matchedFixtures = 0;
    let xgEndpointAvailable = true;

    for (const item of sportmonksFixtures) {
      const startingAt = asString(item.starting_at ?? item.startingAt ?? item.date);
      if (startingAt) {
        const fixtureDay = startingAt.slice(0, 10);
        if (fixtureDay < start || fixtureDay > end) continue;
      }

      const participants = asList(item.participants);
      if (participants.length < 2) continue;

      const homeParticipant =
        participants.find((p) => asString(asObject(asObject(p).meta).location).toLowerCase() === "home") ??
        participants[0];
      const awayParticipant =
        participants.find((p) => asString(asObject(asObject(p).meta).location).toLowerCase() === "away") ??
        participants[1];

      const homeName = asString(asObject(homeParticipant).name);
      const awayName = asString(asObject(awayParticipant).name);
      const homeTeamId = teamNameToId.get(normalizeName(homeName));
      const awayTeamId = teamNameToId.get(normalizeName(awayName));
      if (!homeTeamId || !awayTeamId) continue;

      const fixture = fixtureByTeams.get(`${homeTeamId}:${awayTeamId}`);
      if (!fixture) continue;
      matchedFixtures += 1;

      if (typeof fixture.home_score === "number" && typeof fixture.away_score === "number") {
        const homeWin = fixture.home_score > fixture.away_score;
        const awayWin = fixture.away_score > fixture.home_score;
        const draw = fixture.home_score === fixture.away_score;

        teamFormPayload.push({
          team_id: fixture.home_team_id,
          competition_id: fixture.competition_id,
          season: currentSeason,
          gameweek: fixture.gameweek,
          matches_played: 1,
          wins: homeWin ? 1 : 0,
          draws: draw ? 1 : 0,
          losses: awayWin ? 1 : 0,
          goals_for: fixture.home_score,
          goals_against: fixture.away_score,
          form_points: homeWin ? 3 : draw ? 1 : 0,
          expected_goals_for: 0,
          expected_goals_against: 0,
          raw_stats: { source: "fixture_scores", fixture_id: fixture.id },
          updated_at: new Date().toISOString(),
        });

        teamFormPayload.push({
          team_id: fixture.away_team_id,
          competition_id: fixture.competition_id,
          season: currentSeason,
          gameweek: fixture.gameweek,
          matches_played: 1,
          wins: awayWin ? 1 : 0,
          draws: draw ? 1 : 0,
          losses: homeWin ? 1 : 0,
          goals_for: fixture.away_score,
          goals_against: fixture.home_score,
          form_points: awayWin ? 3 : draw ? 1 : 0,
          expected_goals_for: 0,
          expected_goals_against: 0,
          raw_stats: { source: "fixture_scores", fixture_id: fixture.id },
          updated_at: new Date().toISOString(),
        });
      }

      const fixtureExternalId = asInt(item.id, 0);
      if (fixtureExternalId <= 0) continue;

      const matchCentre = await fetchSportmonks(
        `/fixtures/${fixtureExternalId}?include=participants;scores;events.type;events.player;events.relatedplayer;lineups.details.type;statistics.type;sidelined.type;sidelined.sideline;sidelined.player;sidelined.participant`,
        sportmonksToken,
      );
      const matchData = asObject(matchCentre.data);
      const events = asList(matchData.events);
      const sidelined = asList(matchData.sidelined);

      let xgLineups: unknown[] = [];
      if (xgEndpointAvailable) {
        try {
          const xgResponse = await fetchSportmonks(
            `/fixtures/${fixtureExternalId}/xg?include=participants;lineups.details.type`,
            sportmonksToken,
          );
          xgLineups = asList(asObject(xgResponse.data).lineups);
        } catch {
          xgEndpointAvailable = false;
        }
      }

      const xgByPlayerKey = new Map<string, { xg: number; xa: number }>();
      for (const rawXgLineup of xgLineups) {
        const xgLineup = asObject(rawXgLineup);
        const xgPlayerObj = asObject(xgLineup.player);
        const xgParticipantObj = asObject(xgLineup.participant);
        const xgPlayerName = asString(xgPlayerObj.name, asString(xgLineup.player_name));
        const xgTeamName = asString(xgParticipantObj.name);
        const xgTeamId = teamNameToId.get(normalizeName(xgTeamName));
        if (!xgTeamId || !xgPlayerName) continue;

        let playerXg = 0;
        let playerXa = 0;
        for (const rawDetail of asList(xgLineup.details)) {
          const detail = asObject(rawDetail);
          const type = asObject(detail.type);
          const label = asString(
            type.developer_name,
            asString(type.name, asString(detail.type_name, asString(detail.code))),
          );
          const statKey = normalizeStatKey(label);
          const value = extractStatValue(detail);
          if (isExpectedGoalsKey(statKey)) playerXg += value;
          else if (isExpectedAssistsKey(statKey)) playerXa += value;
        }

        if (playerXg > 0 || playerXa > 0) {
          xgByPlayerKey.set(`${xgTeamId}:${normalizeName(xgPlayerName)}`, {
            xg: playerXg,
            xa: playerXa,
          });
        }
      }

      let eventIndex = 0;
      for (const rawEvent of events) {
        const ev = asObject(rawEvent);
        eventIndex += 1;
        const evType = eventType(ev);
        const player = asObject(ev.player);
        const relatedPlayer = asObject(ev.relatedplayer);

        const primaryPlayerName = asString(player.name);
        const relatedPlayerName = asString(relatedPlayer.name);

        const primaryKeyHome = `${homeTeamId}:${normalizeName(primaryPlayerName)}`;
        const primaryKeyAway = `${awayTeamId}:${normalizeName(primaryPlayerName)}`;
        const relatedKeyHome = `${homeTeamId}:${normalizeName(relatedPlayerName)}`;
        const relatedKeyAway = `${awayTeamId}:${normalizeName(relatedPlayerName)}`;

        const mappedPrimary = playerByTeamAndName.get(primaryKeyHome) ?? playerByTeamAndName.get(primaryKeyAway) ?? null;
        const mappedRelated = playerByTeamAndName.get(relatedKeyHome) ?? playerByTeamAndName.get(relatedKeyAway) ?? null;

        const minute = asInt(ev.minute, 0);

        eventPayload.push({
          fixture_id: fixture.id,
          provider: "sportmonks",
          external_id: `sportmonks:${fixtureExternalId}:event:${asString(ev.id, String(eventIndex))}`,
          event_type: evType || "event",
          minute: minute > 0 ? minute : null,
          team_id: homeTeamId,
          player_id: mappedPrimary?.id ?? null,
          related_player_id: mappedRelated?.id ?? null,
          description: asString(ev.commentary, evType || "Event"),
          raw_event: ev,
          created_at: new Date().toISOString(),
        });

        if (evType.includes("red")) {
          if (mappedPrimary?.id) {
            suspensionsPayload.push({
              player_id: mappedPrimary.id,
              provider: "sportmonks",
              external_id: `sportmonks:${fixtureExternalId}:susp:${asString(ev.id, String(eventIndex))}`,
              season: currentSeason,
              reason: "Red card",
              matches_remaining: 1,
              source_url: null,
              raw_payload: ev,
              updated_at: new Date().toISOString(),
            });
          }
        }

        if (evType.includes("injur")) {
          if (mappedPrimary?.id) {
            injuriesPayload.push({
              player_id: mappedPrimary.id,
              provider: "sportmonks",
              external_id: `sportmonks:${fixtureExternalId}:inj:${asString(ev.id, String(eventIndex))}`,
              season: currentSeason,
              status: "injured",
              reason: asString(ev.commentary, "Injury event"),
              expected_return: null,
              notes: null,
              source_url: null,
              raw_payload: ev,
              updated_at: new Date().toISOString(),
            });
          }
        }
      }

      for (const rawSidelined of sidelined) {
        const s = asObject(rawSidelined);
        const sideline = asObject(s.sideline);
        const typeObj = asObject(s.type);
        const participant = asObject(s.participant);
        const player = asObject(s.player);

        const teamName = asString(participant.name);
        const playerName = asString(player.name, asString(player.display_name));
        const sidelineId = asString(s.sideline_id, asString(s.id));
        const category = asString(sideline.category).toLowerCase();
        const typeName = asString(typeObj.developer_name, asString(typeObj.name));

        const resolvedTeamId = teamNameToId.get(normalizeName(teamName));
        if (!resolvedTeamId || !playerName) continue;

        const mapped = playerByTeamAndName.get(`${resolvedTeamId}:${normalizeName(playerName)}`);
        if (!mapped) continue;

        const externalId = sidelineId.length > 0
          ? `sportmonks:sideline:${sidelineId}`
          : `sportmonks:${fixtureExternalId}:sideline:${asString(s.id, String(mapped.id))}`;

        const isSuspension =
          category.includes("susp") ||
          typeName.toLowerCase().includes("susp") ||
          typeName.toLowerCase().includes("red_card");

        if (isSuspension) {
          suspensionsPayload.push({
            player_id: mapped.id,
            provider: "sportmonks",
            external_id: externalId,
            season: currentSeason,
            reason: typeName || "Suspension",
            matches_remaining: asInt(sideline.games_missed, 0),
            source_url: null,
            raw_payload: s,
            updated_at: new Date().toISOString(),
          });
        } else {
          injuriesPayload.push({
            player_id: mapped.id,
            provider: "sportmonks",
            external_id: externalId,
            season: currentSeason,
            status: Boolean(sideline.completed) ? "resolved" : "injured",
            reason: typeName || "Injury",
            expected_return: asString(sideline.end_date) || null,
            notes: asString(sideline.games_missed).length > 0
              ? `games_missed=${asString(sideline.games_missed)}`
              : null,
            source_url: null,
            raw_payload: s,
            updated_at: new Date().toISOString(),
          });
        }
      }

      const lineups = asList(matchData.lineups);
      for (const rawLineup of lineups) {
        const lineup = asObject(rawLineup);
        const playerObj = asObject(lineup.player);
        const participantObj = asObject(lineup.participant);

        const playerName = asString(playerObj.name, asString(lineup.player_name));
        const teamName = asString(participantObj.name);
        const resolvedTeamId = teamNameToId.get(normalizeName(teamName)) ?? homeTeamId;
        const mapped = playerByTeamAndName.get(`${resolvedTeamId}:${normalizeName(playerName)}`);
        if (!mapped) continue;

        const details = asList(lineup.details);
        let minutes = 0;
        let goals = 0;
        let assists = 0;
        let yellow = 0;
        let red = 0;
        let saves = 0;
        let bonus = 0;
        let xg = 0;
        let xa = 0;
        let keyPasses = 0;
        let chancesCreated = 0;
        let bigChancesCreated = 0;

        for (const rawDetail of details) {
          const detail = asObject(rawDetail);
          const type = asObject(detail.type);
          const label = asString(
            type.developer_name,
            asString(type.name, asString(detail.type_name, asString(detail.code))),
          );
          const statKey = normalizeStatKey(label);
          const value = extractStatValue(detail);

          // Check expected metrics first so they don't get consumed by generic goal/assist matching.
          if (isExpectedGoalsKey(statKey)) xg += value;
          else if (isExpectedAssistsKey(statKey)) xa += value;
          else if (statKey.includes("keypass")) keyPasses += Math.trunc(value);
          else if (statKey.includes("bigchancescreated")) {
            bigChancesCreated += Math.trunc(value);
            chancesCreated += Math.trunc(value);
          }
          else if (statKey.includes("chancecreated") || statKey.includes("chancescreated")) {
            chancesCreated += Math.trunc(value);
          }
          else if (statKey.includes("minute")) minutes = Math.max(minutes, Math.trunc(value));
          else if (statKey.includes("yellow")) yellow += Math.trunc(value);
          else if (statKey.includes("red")) red += Math.trunc(value);
          else if (statKey.includes("save")) saves += Math.trunc(value);
          else if (statKey.includes("bonus")) bonus += Math.trunc(value);
          else if (statKey.includes("assist")) assists += Math.trunc(value);
          else if (statKey.includes("goal")) goals += Math.trunc(value);
        }

        const xgOverride = xgByPlayerKey.get(`${resolvedTeamId}:${normalizeName(playerName)}`);
        if (xgOverride) {
          xg = xgOverride.xg;
          xa = xgOverride.xa;
        }

        if (xa <= 0) {
          xa = deriveExpectedAssists({
            keyPasses,
            bigChancesCreated,
            assists,
          });
        }

        const points = fantasyPoints(mapped.position, {
          goals,
          assists,
          cleanSheet: false,
          yellowCards: yellow,
          redCards: red,
          saves,
          bonus,
        });

        playerStatsPayload.push({
          fixture_id: fixture.id,
          player_id: mapped.id,
          team_id: resolvedTeamId,
          season: currentSeason,
          gameweek: fixture.gameweek,
          minutes,
          goals,
          assists,
          expected_goals: xg,
          expected_assists: xa,
          clean_sheet: false,
          yellow_cards: yellow,
          red_cards: red,
          saves,
          shots: 0,
          shots_on_target: 0,
          passes_completed: 0,
          tackles: 0,
          interceptions: 0,
          bonus,
          raw_stats: lineup,
          updated_at: new Date().toISOString(),
        });

        pointsPayload.push({
          player_id: mapped.id,
          season: currentSeason,
          gameweek: fixture.gameweek,
          fixture_id: fixture.id,
          minutes,
          goals,
          assists,
          expected_goals: xg,
          expected_assists: xa,
          clean_sheet: false,
          yellow_cards: yellow,
          red_cards: red,
          saves,
          bonus,
          points,
          source: "sportmonks-lineups",
          raw_stats: lineup,
          updated_at: new Date().toISOString(),
        });
      }
    }

    if (eventPayload.length > 0) {
      await supabase.from("fd_fixture_events").upsert(eventPayload, {
        onConflict: "provider,external_id",
      });
    }

    const uniqueInjuries = Array.from(new Map(
      injuriesPayload.map((row) => [`${asString(row.player_id)}:${asString(row.season)}:${asString(row.status)}`, row]),
    ).values());

    const uniqueSuspensions = Array.from(new Map(
      suspensionsPayload.map((row) => [`${asString(row.player_id)}:${asString(row.season)}`, row]),
    ).values());

    if (uniqueInjuries.length > 0) {
      await supabase.from("fd_player_injuries").upsert(uniqueInjuries, {
        onConflict: "provider,external_id",
      });
    }

    if (uniqueSuspensions.length > 0) {
      await supabase.from("fd_player_suspensions").upsert(uniqueSuspensions, {
        onConflict: "provider,external_id",
      });
    }

    if (playerStatsPayload.length > 0) {
      await supabase.from("fd_player_match_stats").upsert(playerStatsPayload, {
        onConflict: "fixture_id,player_id",
      });
    }

    if (pointsPayload.length > 0) {
      await supabase.from("fd_player_gameweek_points").upsert(pointsPayload, {
        onConflict: "player_id,season,gameweek,fixture_id",
      });
    }

    if (teamFormPayload.length > 0) {
      await supabase.from("fd_team_form").upsert(teamFormPayload, {
        onConflict: "team_id,season,gameweek",
      });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        season,
        competitionExternalId,
        matchedFixtures,
        upsertedFixtureEvents: eventPayload.length,
        upsertedInjuries: uniqueInjuries.length,
        upsertedSuspensions: uniqueSuspensions.length,
        upsertedPlayerStats: playerStatsPayload.length,
        upsertedGameweekPoints: pointsPayload.length,
        upsertedTeamForm: teamFormPayload.length,
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
