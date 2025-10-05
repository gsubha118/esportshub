-- Seeds: sample_data
-- Description: Insert sample data for development and testing

-- Insert sample games
INSERT INTO games (name, display_name, description, is_active) VALUES
('valorant', 'Valorant', 'Tactical 5v5 character-based shooter game', true),
('lol', 'League of Legends', 'Multiplayer online battle arena game', true),
('csgo', 'Counter-Strike: Global Offensive', 'Tactical first-person shooter', true),
('dota2', 'Dota 2', 'Multiplayer online battle arena game', true),
('rocket-league', 'Rocket League', 'Soccer meets driving game', true)
ON CONFLICT (name) DO NOTHING;

-- Insert admin user (password: admin123 - hashed)
INSERT INTO users (username, email, password_hash, first_name, last_name, role) VALUES
('admin', 'admin@esportsplatform.com', '$2a$10$rQZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8q', 'Admin', 'User', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Insert sample users
INSERT INTO users (username, email, password_hash, first_name, last_name) VALUES
('player1', 'player1@example.com', '$2a$10$rQZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8q', 'John', 'Doe'),
('player2', 'player2@example.com', '$2a$10$rQZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8q', 'Jane', 'Smith'),
('player3', 'player3@example.com', '$2a$10$rQZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8qZ8J8q', 'Mike', 'Johnson')
ON CONFLICT (username) DO NOTHING;

-- Get game IDs for tournaments
DO $$
DECLARE
    valorant_id UUID;
    lol_id UUID;
    csgo_id UUID;
    admin_id UUID;
    player1_id UUID;
    player2_id UUID;
    player3_id UUID;
BEGIN
    SELECT id INTO valorant_id FROM games WHERE name = 'valorant';
    SELECT id INTO lol_id FROM games WHERE name = 'lol';
    SELECT id INTO csgo_id FROM games WHERE name = 'csgo';
    SELECT id INTO admin_id FROM users WHERE username = 'admin';
    SELECT id INTO player1_id FROM users WHERE username = 'player1';
    SELECT id INTO player2_id FROM users WHERE username = 'player2';
    SELECT id INTO player3_id FROM users WHERE username = 'player3';

    -- Insert sample tournaments
    INSERT INTO tournaments (name, description, game_id, created_by, status, tournament_format, max_participants, prize_pool, start_date, registration_deadline, rules) VALUES
    ('Weekly Valorant Championship', 'Join the ultimate Valorant championship where the best teams compete for glory and prizes. This tournament features a single-elimination bracket with matches streamed live.', valorant_id, admin_id, 'upcoming', 'single_elimination', 64, 10000.00, CURRENT_TIMESTAMP + INTERVAL '7 days', CURRENT_TIMESTAMP + INTERVAL '5 days', 'Teams must consist of 5 players. All players must be at least 16 years old. Matches will be played on the latest patch.'),
    ('League of Legends Spring Cup', 'Spring tournament for League of Legends players. Double elimination format with substantial prize pool.', lol_id, admin_id, 'live', 'double_elimination', 32, 25000.00, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '5 days', 'Teams must consist of 5 players. Standard competitive rules apply.'),
    ('CS:GO Weekend Tournament', 'Weekend CS:GO tournament for casual and competitive players.', csgo_id, admin_id, 'completed', 'single_elimination', 16, 5000.00, CURRENT_TIMESTAMP - INTERVAL '7 days', CURRENT_TIMESTAMP - INTERVAL '10 days', '5v5 competitive matches. Standard tournament rules apply.')
    ON CONFLICT DO NOTHING;

    -- Insert sample user statistics
    INSERT INTO user_statistics (user_id, total_tournaments, tournaments_won, tournaments_lost, total_earnings, current_rank, rank_points) VALUES
    (player1_id, 15, 8, 7, 2500.00, 'Gold III', 1850),
    (player2_id, 12, 6, 6, 1800.00, 'Silver II', 1650),
    (player3_id, 8, 3, 5, 900.00, 'Bronze I', 1450)
    ON CONFLICT (user_id) DO UPDATE SET
        total_tournaments = EXCLUDED.total_tournaments,
        tournaments_won = EXCLUDED.tournaments_won,
        tournaments_lost = EXCLUDED.tournaments_lost,
        total_earnings = EXCLUDED.total_earnings,
        current_rank = EXCLUDED.current_rank,
        rank_points = EXCLUDED.rank_points,
        last_updated = CURRENT_TIMESTAMP;
END $$;
