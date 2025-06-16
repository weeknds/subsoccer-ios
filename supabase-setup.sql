-- SubSoccer Supabase Database Schema
-- Run this SQL in your Supabase SQL Editor

-- Enable RLS (Row Level Security)
ALTER DATABASE postgres SET row_security = on;

-- Create teams table
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create players table
CREATE TABLE players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    jersey_number INTEGER NOT NULL,
    position TEXT NOT NULL,
    profile_image_url TEXT,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create matches table
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date TIMESTAMPTZ NOT NULL,
    duration INTEGER NOT NULL DEFAULT 90,
    number_of_halves INTEGER NOT NULL DEFAULT 2,
    has_overtime BOOLEAN NOT NULL DEFAULT false,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create player_stats table
CREATE TABLE player_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    minutes_played INTEGER NOT NULL DEFAULT 0,
    goals INTEGER NOT NULL DEFAULT 0,
    assists INTEGER NOT NULL DEFAULT 0,
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create training_sessions table
CREATE TABLE training_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT,
    date TIMESTAMPTZ,
    duration INTEGER NOT NULL DEFAULT 90,
    location TEXT,
    notes TEXT,
    type TEXT,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create training_attendance table
CREATE TABLE training_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    is_present BOOLEAN NOT NULL DEFAULT false,
    notes TEXT,
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    session_id UUID REFERENCES training_sessions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create training_drills table
CREATE TABLE training_drills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    description TEXT,
    duration INTEGER NOT NULL DEFAULT 15,
    drill_order INTEGER NOT NULL DEFAULT 0,
    session_id UUID REFERENCES training_sessions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (RLS) on all tables
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_drills ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for teams
CREATE POLICY "Users can view their own teams" ON teams
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own teams" ON teams
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own teams" ON teams
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own teams" ON teams
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS policies for players
CREATE POLICY "Users can view players from their teams" ON players
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = players.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert players to their teams" ON players
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = players.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update players from their teams" ON players
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = players.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete players from their teams" ON players
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = players.team_id 
            AND teams.user_id = auth.uid()
        )
    );

-- Create RLS policies for matches
CREATE POLICY "Users can view matches from their teams" ON matches
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = matches.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert matches for their teams" ON matches
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = matches.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update matches from their teams" ON matches
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = matches.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete matches from their teams" ON matches
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = matches.team_id 
            AND teams.user_id = auth.uid()
        )
    );

-- Create RLS policies for player_stats
CREATE POLICY "Users can view stats from their players" ON player_stats
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM players 
            JOIN teams ON teams.id = players.team_id
            WHERE players.id = player_stats.player_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert stats for their players" ON player_stats
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM players 
            JOIN teams ON teams.id = players.team_id
            WHERE players.id = player_stats.player_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update stats from their players" ON player_stats
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM players 
            JOIN teams ON teams.id = players.team_id
            WHERE players.id = player_stats.player_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete stats from their players" ON player_stats
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM players 
            JOIN teams ON teams.id = players.team_id
            WHERE players.id = player_stats.player_id 
            AND teams.user_id = auth.uid()
        )
    );

-- Create RLS policies for training_sessions
CREATE POLICY "Users can view training sessions from their teams" ON training_sessions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = training_sessions.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert training sessions for their teams" ON training_sessions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = training_sessions.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update training sessions from their teams" ON training_sessions
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = training_sessions.team_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete training sessions from their teams" ON training_sessions
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM teams 
            WHERE teams.id = training_sessions.team_id 
            AND teams.user_id = auth.uid()
        )
    );

-- Create RLS policies for training_attendance
CREATE POLICY "Users can view attendance from their sessions" ON training_attendance
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_attendance.session_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert attendance for their sessions" ON training_attendance
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_attendance.session_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update attendance from their sessions" ON training_attendance
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_attendance.session_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete attendance from their sessions" ON training_attendance
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_attendance.session_id 
            AND teams.user_id = auth.uid()
        )
    );

-- Create RLS policies for training_drills
CREATE POLICY "Users can view drills from their sessions" ON training_drills
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_drills.session_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert drills for their sessions" ON training_drills
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_drills.session_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update drills from their sessions" ON training_drills
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_drills.session_id 
            AND teams.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete drills from their sessions" ON training_drills
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM training_sessions 
            JOIN teams ON teams.id = training_sessions.team_id
            WHERE training_sessions.id = training_drills.session_id 
            AND teams.user_id = auth.uid()
        )
    );

-- Create functions to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_matches_updated_at BEFORE UPDATE ON matches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_player_stats_updated_at BEFORE UPDATE ON player_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_training_sessions_updated_at BEFORE UPDATE ON training_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_training_attendance_updated_at BEFORE UPDATE ON training_attendance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_training_drills_updated_at BEFORE UPDATE ON training_drills
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();