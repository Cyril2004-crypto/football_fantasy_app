# Football Manager Companion API

A small Express backend for local development and Postman testing.

## Run

```bash
cd backend
npm install
npm start
```

Create a `.env` (or set shell env vars) using `.env.example` values.

## Default URL

- `http://localhost:3000/api`

## Notes

- Auth source of truth is Firebase (ID tokens are verified server-side).
- DB/league logic goes through Supabase (`users`, `fantasy_teams`) and `league-actions` edge function.
- Keep Postman `baseUrl` as `http://localhost:3000/api`.
