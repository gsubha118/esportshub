-- Seeds: esports_platform_sample_data
-- Description: Insert sample data for the esports platform
-- Compatible with migration 002_esports_platform_schema.sql

-- Insert sample users with different roles
INSERT INTO users (email, role) VALUES
('admin@esportsplatform.com', 'admin'),
('organizer1@esportsplatform.com', 'organizer'),
('organizer2@esportsplatform.com', 'organizer'),
('player1@esportsplatform.com', 'player'),
('player2@esportsplatform.com', 'player'),
('player3@esportsplatform.com', 'player'),
('player4@esportsplatform.com', 'player'),
('player5@esportsplatform.com', 'player')
ON CONFLICT (email) DO NOTHING;

-- Insert sample players
INSERT INTO players (user_id, gamer_tag, game, rank)
SELECT
    u.id,
    'Player' || ROW_NUMBER() OVER (ORDER BY u.id) as gamer_tag,
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY u.id) <= 3 THEN 'Valorant'
        WHEN ROW_NUMBER() OVER (ORDER BY u.id) <= 6 THEN 'League of Legends'
        ELSE 'CS:GO'
    END as game,
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY u.id) = 1 THEN 'Radiant'
        WHEN ROW_NUMBER() OVER (ORDER BY u.id) = 2 THEN 'Immortal'
        WHEN ROW_NUMBER() OVER (ORDER BY u.id) = 3 THEN 'Diamond'
        WHEN ROW_NUMBER() OVER (ORDER BY u.id) = 4 THEN 'Challenger'
        WHEN ROW_NUMBER() OVER (ORDER BY u.id) = 5 THEN 'Master'
        ELSE 'Gold'
    END as rank
FROM users u
WHERE u.role = 'player'
ON CONFLICT (gamer_tag) DO NOTHING;

-- Insert sample teams
INSERT INTO teams (name, owner_user_id)
SELECT
    'Team ' || t.name,
    u.id
FROM (
    SELECT 'Alpha' as name UNION ALL
    SELECT 'Beta' as name UNION ALL
    SELECT 'Gamma' as name UNION ALL
    SELECT 'Delta' as name
) t
CROSS JOIN (
    SELECT id FROM users WHERE role = 'player' LIMIT 1
) u
ON CONFLICT (name) DO NOTHING;

-- Insert team members
INSERT INTO team_members (team_id, player_id, role)
SELECT
    tm1.team_id,
    p.id,
    CASE
        WHEN ROW_NUMBER() OVER (PARTITION BY tm1.team_id ORDER BY p.id) = 1 THEN 'captain'
        ELSE 'member'
    END as role
FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) as rn
    FROM teams
) tm1
JOIN players p ON MOD(p.id::text::int + tm1.rn, 3) = 0
ON CONFLICT (team_id, player_id) DO NOTHING;

-- Insert sample events
INSERT INTO events (organizer_id, title, description, game, start_time, end_time, bracket_type, max_teams)
SELECT
    u.id,
    'Weekly ' || e.game || ' Championship #' || ROW_NUMBER() OVER (ORDER BY e.game),
    'Join our weekly championship for ' || e.game || ' players. Compete against the best and win amazing prizes!',
    e.game,
    CURRENT_TIMESTAMP + INTERVAL '1 week' + (ROW_NUMBER() OVER (ORDER BY e.game) || ' days')::INTERVAL,
    CURRENT_TIMESTAMP + INTERVAL '1 week' + INTERVAL '1 day' + (ROW_NUMBER() OVER (ORDER BY e.game) || ' days')::INTERVAL,
    e.bracket_type,
    8
FROM (
    SELECT 'Valorant' as game, 'single_elimination' as bracket_type UNION ALL
    SELECT 'League of Legends' as game, 'double_elimination' as bracket_type UNION ALL
    SELECT 'CS:GO' as game, 'single_elimination' as bracket_type
) e
CROSS JOIN (
    SELECT id FROM users WHERE role = 'organizer' LIMIT 1
) u
ON CONFLICT DO NOTHING;

-- Insert sample tickets for events
INSERT INTO tickets (event_id, user_id, status, amount)
SELECT
    e.id,
    u.id,
    CASE
        WHEN RANDOM() < 0.3 THEN 'paid'
        ELSE 'pending'
    END as status,
    CASE
        WHEN RANDOM() < 0.3 THEN 25.00
        ELSE NULL
    END as amount
FROM events e
CROSS JOIN (
    SELECT id FROM users WHERE role = 'player' LIMIT 3
) u
WHERE RANDOM() < 0.7  -- Only 70% of possible tickets
ON CONFLICT DO NOTHING;

-- Insert sample matches for completed events
DO $$
DECLARE
    event_record RECORD;
    team_record1 RECORD;
    team_record2 RECORD;
    match_round INTEGER;
    winner_team UUID;
BEGIN
    -- For each completed event, create some matches
    FOR event_record IN SELECT id FROM events WHERE status = 'completed' LIMIT 2 LOOP
        match_round := 1;

        -- Create first round matches
        FOR team_record1 IN
            SELECT id FROM teams ORDER BY id LIMIT 4
        LOOP
            -- Get opponent team (simple round-robin for demo)
            SELECT id INTO team_record2 FROM teams
            WHERE id != team_record1.id
            ORDER BY id LIMIT 1;

            -- Randomly determine winner
            IF RANDOM() < 0.5 THEN
                winner_team := team_record1.id;
            ELSE
                winner_team := team_record2.id;
            END IF;

            INSERT INTO matches (event_id, round, match_number, team1_id, team2_id, score1, score2, winner_id, status)
            VALUES (
                event_record.id,
                match_round,
                (SELECT COALESCE(MAX(match_number), 0) + 1 FROM matches WHERE event_id = event_record.id AND round = match_round),
                team_record1.id,
                team_record2.id,
                FLOOR(RANDOM() * 3),
                FLOOR(RANDOM() * 3),
                winner_team,
                'completed'
            );
        END LOOP;
    END LOOP;
END $$;
