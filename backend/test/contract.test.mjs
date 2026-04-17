import test from 'node:test';
import assert from 'node:assert/strict';
import { app, buildLeagueActionPayload, toTeamResponse } from '../server.js';

function startServer() {
  return new Promise((resolve) => {
    const server = app.listen(0, () => {
      const address = server.address();
      const port = typeof address === 'object' && address ? address.port : 0;
      resolve({ server, baseUrl: `http://127.0.0.1:${port}` });
    });
  });
}

test('buildLeagueActionPayload maps league action requests correctly', () => {
  const payload = buildLeagueActionPayload(
    'createLeague',
    {
      uid: 'user-123',
      email: 'user@example.com',
      displayName: 'Test User'
    },
    {
      name: 'Friday League',
      type: 'public',
      teamName: 'Test XI',
      totalPoints: 120,
      gameweekPoints: 18,
      remainingBudget: 2.5
    }
  );

  assert.deepEqual(payload, {
    action: 'createLeague',
    userId: 'user-123',
    userName: 'Test User',
    email: 'user@example.com',
    name: 'Friday League',
    type: 'public',
    teamName: 'Test XI',
    totalPoints: 120,
    gameweekPoints: 18,
    remainingBudget: 2.5
  });
});

test('toTeamResponse maps Supabase rows into API schema', () => {
  const team = toTeamResponse({
    id: 7,
    user_id: 'user-123',
    team_name: 'Test XI',
    total_points: 402,
    gameweek_points: 34,
    remaining_budget: 1.5,
    updated_at: '2026-04-17T10:00:00.000Z'
  });

  assert.deepEqual(team, {
    id: '7',
    userId: 'user-123',
    name: 'Test XI',
    players: [],
    remainingBudget: 1.5,
    totalPoints: 402,
    gameweekPoints: 34,
    createdAt: '2026-04-17T10:00:00.000Z',
    updatedAt: '2026-04-17T10:00:00.000Z'
  });
});

test('health endpoint exposes required contract fields', async () => {
  const { server, baseUrl } = await startServer();
  try {
    const response = await fetch(`${baseUrl}/api/health`);
    assert.equal(response.status, 200);

    const body = await response.json();
    assert.equal(body.success, true);
    assert.equal(body.status, 'ok');
    assert.equal(body.service, 'football-manager-companion-api');
    assert.ok(typeof body.port === 'number');
    assert.ok('firebaseProjectId' in body);
    assert.ok('supabaseConfigured' in body);
    assert.ok('leagueFunctionConfigured' in body);
  } finally {
    server.close();
  }
});
