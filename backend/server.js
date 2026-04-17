import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { pathToFileURL } from 'url';

export const app = express();
const PORT = Number(process.env.PORT || 3000);
const API_BASE = '/api';
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'football-fantasy-app-498ac';
const FIREBASE_WEB_API_KEY = process.env.FIREBASE_WEB_API_KEY || '';
const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const SUPABASE_LEAGUE_FUNCTION_URL =
  process.env.SUPABASE_LEAGUE_FUNCTION_URL ||
  (SUPABASE_URL ? `${SUPABASE_URL.replace('.supabase.co', '.functions.supabase.co')}/league-actions` : '');

const firebaseJwks = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com')
);

const supabaseAdmin =
  SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
    ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false }
      })
    : null;

app.use(cors());
app.use(express.json());

const samplePlayers = [
  { id: '1', name: 'Player One', clubId: 'club-1', clubName: 'Club One', position: 'midfielder', price: 8.0, points: 100, gameweekPoints: 10, nationality: 'GB' },
  { id: '2', name: 'Player Two', clubId: 'club-2', clubName: 'Club Two', position: 'forward', price: 7.5, points: 80, gameweekPoints: 7, nationality: 'GB' },
  { id: '3', name: 'Player Three', clubId: 'club-3', clubName: 'Club Three', position: 'defender', price: 6.0, points: 60, gameweekPoints: 6, nationality: 'GB' }
];

const requireSupabase = (res) => {
  if (supabaseAdmin) return true;
  res.status(500).json({
    message: 'Supabase server env is not configured',
    required: ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY']
  });
  return false;
};

export const toTeamResponse = (row, players = []) => ({
  id: String(row?.id || ''),
  userId: String(row?.user_id || ''),
  name: String(row?.team_name || 'My Team'),
  players,
  remainingBudget: Number(row?.remaining_budget || 0),
  totalPoints: Number(row?.total_points || 0),
  gameweekPoints: Number(row?.gameweek_points || 0),
  createdAt: new Date(row?.updated_at || Date.now()).toISOString(),
  updatedAt: row?.updated_at ? new Date(row.updated_at).toISOString() : null
});

export const buildLeagueActionPayload = (action, user, body = {}) => ({
  action,
  userId: user.uid,
  userName: user.displayName || user.email,
  email: user.email,
  ...body
});

const ensureUserRow = async (firebaseUid, email, displayName) => {
  if (!supabaseAdmin) return;

  const payload = {
    firebase_uid: firebaseUid,
    email: email || `${firebaseUid}@local.invalid`,
    username: displayName || null,
    updated_at: new Date().toISOString()
  };

  const { error } = await supabaseAdmin.from('users').upsert(payload, { onConflict: 'firebase_uid' });
  if (error) {
    throw new Error(`Failed to sync user row: ${error.message}`);
  }
};

const verifyFirebaseToken = async (idToken) => {
  const { payload } = await jwtVerify(idToken, firebaseJwks, {
    issuer: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    audience: FIREBASE_PROJECT_ID
  });

  const uid = typeof payload.user_id === 'string' ? payload.user_id : typeof payload.sub === 'string' ? payload.sub : null;
  if (!uid) {
    throw new Error('Invalid token payload: missing user id');
  }

  return {
    uid,
    email: typeof payload.email === 'string' ? payload.email : '',
    displayName: typeof payload.name === 'string' ? payload.name : '',
    payload
  };
};

const firebaseAuthRequest = async (endpoint, body) => {
  if (!FIREBASE_WEB_API_KEY) {
    throw new Error('FIREBASE_WEB_API_KEY is not configured in backend env');
  }

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:${endpoint}?key=${FIREBASE_WEB_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...body, returnSecureToken: true })
    }
  );

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = data?.error?.message || 'Firebase auth request failed';
    throw new Error(message);
  }

  return data;
};

const invokeLeagueAction = async (action, user, body = {}) => {
  if (!SUPABASE_LEAGUE_FUNCTION_URL) {
    throw new Error('SUPABASE_LEAGUE_FUNCTION_URL is not configured');
  }

  const response = await fetch(SUPABASE_LEAGUE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${user.idToken}`
    },
    body: JSON.stringify(buildLeagueActionPayload(action, user, body))
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data?.error || `League action failed: ${response.status}`);
  }

  return data;
};

const authRequired = (req, res, next) => {
  (async () => {
    try {
      const header = String(req.headers.authorization || '').trim();

      // Be defensive with client formatting issues (double Bearer, quotes, whitespace).
      let token = header.replace(/^Bearer\s+/i, '').trim();
      token = token.replace(/^Bearer\s+/i, '').trim();
      token = token.replace(/^"|"$/g, '').trim();

      if (!token) {
        return res.status(401).json({ message: 'Missing bearer token' });
      }

      if (/^\{\{.+\}\}$/.test(token)) {
        return res.status(401).json({
          message: 'Unauthorized: auth token variable was not resolved (check Postman environment authToken)'
        });
      }

      // JWT must have 3 dot-separated parts.
      if (token.split('.').length !== 3) {
        return res.status(401).json({
          message: 'Unauthorized: malformed token (expected JWT with 3 sections)'
        });
      }

      const verified = await verifyFirebaseToken(token);
      req.user = {
        uid: verified.uid,
        email: verified.email,
        displayName: verified.displayName,
        idToken: token
      };

      await ensureUserRow(verified.uid, verified.email, verified.displayName);
      next();
    } catch (error) {
      res.status(401).json({ message: `Unauthorized: ${error instanceof Error ? error.message : String(error)}` });
    }
  })();
};

app.get(`${API_BASE}/health`, (_req, res) => {
  res.json({
    success: true,
    status: 'ok',
    port: PORT,
    service: 'football-manager-companion-api',
    firebaseProjectId: FIREBASE_PROJECT_ID,
    supabaseConfigured: Boolean(supabaseAdmin),
    leagueFunctionConfigured: Boolean(SUPABASE_LEAGUE_FUNCTION_URL)
  });
});

app.post(`${API_BASE}/auth/register`, (req, res) => {
  (async () => {
    try {
      const { email, password, displayName } = req.body || {};
      if (!email || !password) {
        return res.status(400).json({ message: 'email and password are required' });
      }

      const created = await firebaseAuthRequest('signUp', {
        email,
        password,
        displayName: displayName || undefined
      });

      const verified = await verifyFirebaseToken(created.idToken);
      await ensureUserRow(verified.uid, verified.email, displayName || verified.displayName);

      return res.status(201).json({
        token: created.idToken,
        idToken: created.idToken,
        accessToken: created.idToken,
        refreshToken: created.refreshToken,
        user: {
          id: verified.uid,
          email: verified.email,
          displayName: displayName || verified.displayName
        },
        data: {
          token: created.idToken,
          idToken: created.idToken,
          accessToken: created.idToken
        }
      });
    } catch (error) {
      return res.status(400).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.post(`${API_BASE}/auth/login`, (req, res) => {
  (async () => {
    try {
      const { email, password } = req.body || {};
      if (!email || !password) {
        return res.status(400).json({ message: 'email and password are required' });
      }

      const signedIn = await firebaseAuthRequest('signInWithPassword', { email, password });
      const verified = await verifyFirebaseToken(signedIn.idToken);
      await ensureUserRow(verified.uid, verified.email, verified.displayName);

      return res.json({
        token: signedIn.idToken,
        idToken: signedIn.idToken,
        accessToken: signedIn.idToken,
        refreshToken: signedIn.refreshToken,
        user: {
          id: verified.uid,
          email: verified.email,
          displayName: verified.displayName
        },
        data: {
          token: signedIn.idToken,
          idToken: signedIn.idToken,
          accessToken: signedIn.idToken
        }
      });
    } catch (error) {
      return res.status(400).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.post(`${API_BASE}/auth/logout`, authRequired, (req, res) => {
  res.json({ success: true, message: 'Logged out (client should discard Firebase token)' });
});

app.get(`${API_BASE}/users/profile`, authRequired, (req, res) => {
  res.json({
    data: {
      id: req.user.uid,
      email: req.user.email,
      displayName: req.user.displayName
    }
  });
});

app.get(`${API_BASE}/users/:id`, authRequired, (req, res) => {
  (async () => {
    try {
      if (!requireSupabase(res)) return;

      const { data, error } = await supabaseAdmin
        .from('users')
        .select('firebase_uid, email, username, created_at, updated_at')
        .eq('firebase_uid', req.params.id)
        .limit(1)
        .maybeSingle();

      if (error) {
        return res.status(500).json({ message: error.message });
      }
      if (!data) {
        return res.status(404).json({ message: 'User not found' });
      }

      return res.json({
        data: {
          id: data.firebase_uid,
          email: data.email,
          displayName: data.username,
          createdAt: data.created_at,
          updatedAt: data.updated_at
        }
      });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/players`, authRequired, (_req, res) => {
  (async () => {
    try {
      if (!requireSupabase(res)) return;

      const { data, error } = await supabaseAdmin
        .from('fd_players')
        .select('external_id, team_id, name, position, nationality, price')
        .eq('provider', 'football-data')
        .eq('is_active', true)
        .order('name')
        .limit(100);

      if (error) {
        return res.status(500).json({ message: error.message });
      }

      const rows = (data ?? []).map((row) => ({
        id: String(row.external_id ?? ''),
        name: row.name,
        clubId: row.team_id ? String(row.team_id) : '',
        clubName: '',
        position: (row.position || '').toLowerCase(),
        price: Number(row.price || 0),
        points: 0,
        gameweekPoints: 0,
        nationality: row.nationality || ''
      }));

      return res.json({ data: rows });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/players/position`, authRequired, (req, res) => {
  const position = String(req.query.position || '').toLowerCase();
  const filtered = samplePlayers.filter((player) => player.position === position);
  res.json({ data: filtered });
});

app.get(`${API_BASE}/players/team`, authRequired, (req, res) => {
  const teamId = String(req.query.teamId || '');
  const filtered = samplePlayers.filter((player) => player.clubId === teamId);
  res.json({ data: filtered });
});

app.get(`${API_BASE}/players/:id`, authRequired, (req, res) => {
  const player = samplePlayers.find((item) => item.id === req.params.id);
  if (!player) return res.status(404).json({ message: 'Player not found' });
  res.json({ data: player });
});

const getMyTeamHandler = (req, res) => {
  (async () => {
    try {
      if (!requireSupabase(res)) return;

      const { data, error } = await supabaseAdmin
        .from('fantasy_teams')
        .select('id, user_id, team_name, total_points, gameweek_points, remaining_budget, updated_at')
        .eq('user_id', req.user.uid)
        .limit(1)
        .maybeSingle();

      if (error) {
        return res.status(500).json({ message: error.message });
      }
      if (!data) {
        return res.json({ data: null });
      }

      return res.json({ data: toTeamResponse(data) });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
};

app.get(`${API_BASE}/teams/my-team`, authRequired, getMyTeamHandler);
app.get(`${API_BASE}/teams/my-teams`, authRequired, getMyTeamHandler);
app.get(`${API_BASE}/team/my-team`, authRequired, getMyTeamHandler);
app.get(`${API_BASE}/team/my-teams`, authRequired, getMyTeamHandler);

app.post(`${API_BASE}/teams/create`, authRequired, (req, res) => {
  (async () => {
    try {
      if (!requireSupabase(res)) return;

      const { name } = req.body || {};
      const payload = {
        user_id: req.user.uid,
        user_name: req.user.displayName || req.user.email || null,
        team_name: name || 'My Team',
        total_points: 0,
        gameweek_points: 0,
        remaining_budget: 0,
        updated_at: new Date().toISOString()
      };

      const { data, error } = await supabaseAdmin
        .from('fantasy_teams')
        .upsert(payload, { onConflict: 'user_id' })
        .select('id, user_id, team_name, total_points, gameweek_points, remaining_budget, updated_at')
        .limit(1)
        .maybeSingle();

      if (error) {
        return res.status(500).json({ message: error.message });
      }

      return res.status(201).json({ data: toTeamResponse(data || payload) });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.put(`${API_BASE}/teams/update`, authRequired, (req, res) => {
  (async () => {
    try {
      if (!requireSupabase(res)) return;

      const { name } = req.body || {};
      const updatePayload = {
        team_name: name || 'My Team',
        updated_at: new Date().toISOString()
      };

      const { data, error } = await supabaseAdmin
        .from('fantasy_teams')
        .update(updatePayload)
        .eq('user_id', req.user.uid)
        .select('id, user_id, team_name, total_points, gameweek_points, remaining_budget, updated_at')
        .limit(1)
        .maybeSingle();

      if (error) {
        return res.status(500).json({ message: error.message });
      }
      if (!data) {
        return res.status(404).json({ message: 'Team not found for this user' });
      }

      return res.json({ data: toTeamResponse(data) });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/teams/:id`, authRequired, (req, res) => {
  (async () => {
    try {
      if (!requireSupabase(res)) return;

      const { data, error } = await supabaseAdmin
        .from('fantasy_teams')
        .select('id, user_id, team_name, total_points, gameweek_points, remaining_budget, updated_at')
        .eq('id', req.params.id)
        .limit(1)
        .maybeSingle();

      if (error) {
        return res.status(500).json({ message: error.message });
      }
      if (!data) {
        return res.status(404).json({ message: 'Team not found' });
      }

      return res.json({ data: toTeamResponse(data) });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/leagues`, authRequired, (_req, res) => {
  (async () => {
    try {
      const data = await invokeLeagueAction('publicLeagues', _req.user);
      return res.json({ data: data.data || [] });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.post(`${API_BASE}/leagues/create`, authRequired, (req, res) => {
  (async () => {
    try {
      const payload = req.body || {};
      const data = await invokeLeagueAction('createLeague', req.user, {
        name: payload.name,
        type: payload.type,
        teamName: payload.teamName,
        totalPoints: payload.totalPoints,
        gameweekPoints: payload.gameweekPoints,
        remainingBudget: payload.remainingBudget
      });
      return res.status(201).json({ data: data.data });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.post(`${API_BASE}/leagues/join`, authRequired, (req, res) => {
  (async () => {
    try {
      const payload = req.body || {};
      const data = await invokeLeagueAction('joinLeague', req.user, {
        leagueId: payload.leagueId,
        leagueCode: payload.leagueCode,
        teamName: payload.teamName,
        totalPoints: payload.totalPoints,
        gameweekPoints: payload.gameweekPoints,
        remainingBudget: payload.remainingBudget
      });
      return res.json({ data: data.data });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/leagues/standings`, authRequired, (_req, res) => {
  (async () => {
    try {
      const leagueId = String(_req.query.leagueId || '');
      if (!leagueId) {
        return res.status(400).json({ message: 'leagueId query param is required' });
      }
      const data = await invokeLeagueAction('standings', _req.user, { leagueId });
      return res.json({ data: data.data || [] });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/leagues/my-leagues`, authRequired, (_req, res) => {
  (async () => {
    try {
      const data = await invokeLeagueAction('myLeagues', _req.user);
      return res.json({ data: data.data || [] });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/leagues/:id`, authRequired, (req, res) => {
  (async () => {
    try {
      const data = await invokeLeagueAction('myLeagues', req.user);
      const found = (data.data || []).find((league) => String(league.id) === String(req.params.id));
      if (!found) {
        return res.status(404).json({ message: 'League not found' });
      }
      return res.json({ data: found });
    } catch (error) {
      return res.status(500).json({ message: error instanceof Error ? error.message : String(error) });
    }
  })();
});

app.get(`${API_BASE}/matches`, authRequired, (_req, res) => {
  res.json({ data: [] });
});
app.get(`${API_BASE}/matches/live`, authRequired, (_req, res) => res.json({ data: [] }));
app.get(`${API_BASE}/matches/upcoming`, authRequired, (_req, res) => res.json({ data: [] }));
app.get(`${API_BASE}/matches/completed`, authRequired, (_req, res) => res.json({ data: [] }));
app.get(`${API_BASE}/matches/:id`, authRequired, (req, res) => res.json({ data: { id: req.params.id } }));

app.get(`${API_BASE}/stats/gameweek`, authRequired, (_req, res) => res.json({ data: { gameweek: 1, points: 0 } }));
app.get(`${API_BASE}/stats/overall`, authRequired, (_req, res) => res.json({ data: { totalPoints: 0 } }));

app.get(`${API_BASE}/news`, (_req, res) => res.json({ data: [] }));
app.get(`${API_BASE}/tips`, (_req, res) => res.json({ data: [] }));

app.use((req, res) => {
  res.status(404).json({ message: `Route not found: ${req.method} ${req.originalUrl}` });
});

const isMainModule = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMainModule) {
  app.listen(PORT, () => {
    console.log(`Football Manager Companion API running on http://localhost:${PORT}${API_BASE}`);
  });
}
