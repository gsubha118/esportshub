-- Migration: 002_esports_platform_schema
-- Description: Create core esports platform database schema
-- Created: 2024-01-01

-- Enable UUID extension for better ID management
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table - Core user management
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(20) DEFAULT 'player' CHECK (role IN ('player', 'organizer', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT users_email_valid CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Players table - Gaming profiles for users
CREATE TABLE players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    gamer_tag VARCHAR(50) UNIQUE NOT NULL,
    game VARCHAR(100) NOT NULL,
    rank VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT players_gamer_tag_length CHECK (char_length(gamer_tag) >= 3),
    CONSTRAINT players_game_not_empty CHECK (char_length(game) > 0)
);

-- Teams table - Competitive teams
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT teams_name_length CHECK (char_length(name) >= 3)
);

-- Team members table - Junction table for team-player relationships
CREATE TABLE team_members (
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('captain', 'member', 'substitute')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (team_id, player_id),

    -- Constraints
    CONSTRAINT team_members_no_duplicate_players UNIQUE (team_id, player_id)
);

-- Events table - Tournament/competition events
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organizer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    game VARCHAR(100) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    bracket_type VARCHAR(50) DEFAULT 'single_elimination' CHECK (bracket_type IN ('single_elimination', 'double_elimination', 'round_robin', 'swiss')),
    organizer_checkout_url TEXT,
    max_teams INTEGER,
    current_teams INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'live', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT events_title_length CHECK (char_length(title) >= 5),
    CONSTRAINT events_end_after_start CHECK (end_time > start_time),
    CONSTRAINT events_bracket_type_valid CHECK (bracket_type IN ('single_elimination', 'double_elimination', 'round_robin', 'swiss'))
);

-- Tickets table - Event registration and payment tracking
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled', 'refunded')),
    external_payment_ref VARCHAR(255),
    amount DECIMAL(10,2),
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP WITH TIME ZONE,

    -- Constraints
    CONSTRAINT tickets_amount_positive CHECK (amount IS NULL OR amount >= 0)
);

-- Matches table - Individual matches within events
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    round INTEGER NOT NULL,
    match_number INTEGER NOT NULL,
    team1_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    team2_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    score1 INTEGER DEFAULT 0,
    score2 INTEGER DEFAULT 0,
    winner_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'completed', 'cancelled')),
    scheduled_time TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    stream_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT matches_different_teams CHECK (team1_id IS NULL OR team2_id IS NULL OR team1_id != team2_id),
    CONSTRAINT matches_round_positive CHECK (round >= 1),
    CONSTRAINT matches_scores_non_negative CHECK (score1 >= 0 AND score2 >= 0),

    -- Ensure unique match numbers per round per event
    CONSTRAINT unique_match_per_round_event UNIQUE (event_id, round, match_number)
);

-- Create indexes for better performance

-- Users indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Players indexes
CREATE INDEX idx_players_user_id ON players(user_id);
CREATE INDEX idx_players_gamer_tag ON players(gamer_tag);
CREATE INDEX idx_players_game ON players(game);

-- Teams indexes
CREATE INDEX idx_teams_owner_user_id ON teams(owner_user_id);
CREATE INDEX idx_teams_name ON teams(name);

-- Team members indexes
CREATE INDEX idx_team_members_player_id ON team_members(player_id);
CREATE INDEX idx_team_members_role ON team_members(role);

-- Events indexes
CREATE INDEX idx_events_organizer_id ON events(organizer_id);
CREATE INDEX idx_events_game ON events(game);
CREATE INDEX idx_events_start_time ON events(start_time);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_bracket_type ON events(bracket_type);

-- Tickets indexes
CREATE INDEX idx_tickets_event_id ON tickets(event_id);
CREATE INDEX idx_tickets_user_id ON tickets(user_id);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_external_payment_ref ON tickets(external_payment_ref);

-- Matches indexes
CREATE INDEX idx_matches_event_id ON matches(event_id);
CREATE INDEX idx_matches_round ON matches(event_id, round);
CREATE INDEX idx_matches_teams ON matches(team1_id, team2_id);
CREATE INDEX idx_matches_winner_id ON matches(winner_id);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_scheduled_time ON matches(scheduled_time);

-- Create updated_at trigger function for auto-updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at columns
CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to update team count when tickets are purchased
CREATE OR REPLACE FUNCTION update_event_team_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Only count paid tickets as registered teams
        IF NEW.status = 'paid' THEN
            UPDATE events SET current_teams = current_teams + 1 WHERE id = NEW.event_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Only decrement for paid tickets being removed
        IF OLD.status = 'paid' THEN
            UPDATE events SET current_teams = current_teams - 1 WHERE id = OLD.event_id;
        END IF;
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle status changes
        IF OLD.status != NEW.status THEN
            IF OLD.status = 'paid' THEN
                UPDATE events SET current_teams = current_teams - 1 WHERE id = NEW.event_id;
            END IF;
            IF NEW.status = 'paid' THEN
                UPDATE events SET current_teams = current_teams + 1 WHERE id = NEW.event_id;
            END IF;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Create trigger for ticket status changes
CREATE TRIGGER update_event_team_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON tickets
    FOR EACH ROW EXECUTE FUNCTION update_event_team_count();

-- Create function to validate match winner
CREATE OR REPLACE FUNCTION validate_match_winner()
RETURNS TRIGGER AS $$
BEGIN
    -- Only validate when match is completed
    IF NEW.status = 'completed' AND NEW.winner_id IS NOT NULL THEN
        -- Winner must be one of the teams in the match
        IF NEW.winner_id NOT IN (NEW.team1_id, NEW.team2_id) THEN
            RAISE EXCEPTION 'Winner must be one of the teams participating in the match';
        END IF;

        -- If there's a winner, scores should indicate a winner
        IF NEW.team1_id IS NOT NULL AND NEW.team2_id IS NOT NULL THEN
            IF NEW.winner_id = NEW.team1_id AND NEW.score1 <= NEW.score2 THEN
                RAISE EXCEPTION 'Team 1 cannot win if their score is not higher than Team 2';
            END IF;
            IF NEW.winner_id = NEW.team2_id AND NEW.score2 <= NEW.score1 THEN
                RAISE EXCEPTION 'Team 2 cannot win if their score is not higher than Team 1';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for match winner validation
CREATE TRIGGER validate_match_winner_trigger
    BEFORE UPDATE ON matches
    FOR EACH ROW
    WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
    EXECUTE FUNCTION validate_match_winner();

-- Add comments for documentation
COMMENT ON TABLE users IS 'Core user accounts for the esports platform';
COMMENT ON TABLE players IS 'Gaming profiles and statistics for users';
COMMENT ON TABLE teams IS 'Competitive teams that participate in events';
COMMENT ON TABLE team_members IS 'Association between teams and players with roles';
COMMENT ON TABLE events IS 'Tournament and competition events';
COMMENT ON TABLE tickets IS 'Event registration and payment tracking';
COMMENT ON TABLE matches IS 'Individual matches within events';

COMMENT ON COLUMN users.role IS 'User role: player, organizer, or admin';
COMMENT ON COLUMN players.gamer_tag IS 'Unique gaming username/handle';
COMMENT ON COLUMN players.rank IS 'Current competitive rank in the game';
COMMENT ON COLUMN events.bracket_type IS 'Tournament format: single_elimination, double_elimination, round_robin, or swiss';
COMMENT ON COLUMN events.organizer_checkout_url IS 'Payment URL for event registration fees';
COMMENT ON COLUMN tickets.status IS 'Ticket status: pending, paid, cancelled, or refunded';
COMMENT ON COLUMN tickets.external_payment_ref IS 'Reference ID from external payment processor';
COMMENT ON COLUMN matches.bracket_type IS 'Match format within the event';

-- Create a view for active events with team counts
CREATE VIEW active_events AS
SELECT
    e.*,
    COALESCE(t.team_count, 0) as registered_teams
FROM events e
LEFT JOIN (
    SELECT
        event_id,
        COUNT(*) as team_count
    FROM tickets
    WHERE status = 'paid'
    GROUP BY event_id
) t ON e.id = t.event_id
WHERE e.status IN ('published', 'live');

-- Create a view for team standings in events
CREATE VIEW team_standings AS
SELECT
    m.event_id,
    t.name as team_name,
    COUNT(CASE WHEN m.winner_id = t.id THEN 1 END) as wins,
    COUNT(m.id) as matches_played,
    ROUND(
        COUNT(CASE WHEN m.winner_id = t.id THEN 1 END)::numeric /
        NULLIF(COUNT(m.id), 0) * 100, 2
    ) as win_percentage
FROM matches m
JOIN teams t ON (t.id = m.team1_id OR t.id = m.team2_id)
WHERE m.status = 'completed'
GROUP BY m.event_id, t.id, t.name
ORDER BY m.event_id, wins DESC, win_percentage DESC;
