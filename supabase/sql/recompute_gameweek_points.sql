-- Recompute fd_player_gameweek_points.points using current fantasy scoring rules.
-- Run this whenever new rows are inserted/updated in fd_player_gameweek_points.

update public.fd_player_gameweek_points gp
set points =
  (
    -- Goals by position
    case lower(coalesce(p.position, ''))
      when 'goalkeeper' then coalesce(gp.goals, 0) * 10
      when 'gk' then coalesce(gp.goals, 0) * 10
      when 'defender' then coalesce(gp.goals, 0) * 6
      when 'def' then coalesce(gp.goals, 0) * 6
      when 'midfielder' then coalesce(gp.goals, 0) * 5
      when 'mid' then coalesce(gp.goals, 0) * 5
      when 'forward' then coalesce(gp.goals, 0) * 4
      when 'fwd' then coalesce(gp.goals, 0) * 4
      else coalesce(gp.goals, 0) * 5
    end
    -- Assists
    + (coalesce(gp.assists, 0) * 3)
    -- Clean sheets for GK/DEF only
    + (
      case
        when coalesce(gp.clean_sheet, false)
             and lower(coalesce(p.position, '')) in ('goalkeeper', 'gk', 'defender', 'def')
          then 4
        else 0
      end
    )
    -- Discipline and bonus (optional, but useful)
    + coalesce(gp.bonus, 0)
    - coalesce(gp.yellow_cards, 0)
    - (coalesce(gp.red_cards, 0) * 3)
    -- Saves bonus: +1 per 3 saves for goalkeepers
    + (
      case
        when lower(coalesce(p.position, '')) in ('goalkeeper', 'gk')
          then floor(coalesce(gp.saves, 0) / 3.0)::int
        else 0
      end
    )
  ),
  updated_at = now()
from public.fd_players p
where p.id = gp.player_id;
