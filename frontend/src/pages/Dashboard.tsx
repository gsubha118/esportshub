import React, { useState, useEffect } from 'react';

interface UserStats {
  totalTournaments: number;
  wins: number;
  losses: number;
  winRate: number;
  currentRank: string;
  totalEarnings: number;
}

interface RecentMatch {
  id: string;
  tournamentName: string;
  opponent: string;
  result: 'win' | 'loss';
  date: string;
  score?: string;
}

const Dashboard: React.FC = () => {
  const [userStats, setUserStats] = useState<UserStats | null>(null);
  const [recentMatches, setRecentMatches] = useState<RecentMatch[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Simulate API call
    const fetchDashboardData = async () => {
      setLoading(true);
      // Mock data - in real app this would be an API call
      const mockStats: UserStats = {
        totalTournaments: 15,
        wins: 8,
        losses: 7,
        winRate: 53.3,
        currentRank: 'Gold III',
        totalEarnings: 2500
      };

      const mockMatches: RecentMatch[] = [
        {
          id: '1',
          tournamentName: 'Weekly Championship',
          opponent: 'Team Alpha',
          result: 'win',
          date: '2024-01-10T20:00:00Z',
          score: '13-8'
        },
        {
          id: '2',
          tournamentName: 'Speedrun Challenge',
          opponent: 'Team Beta',
          result: 'loss',
          date: '2024-01-08T19:30:00Z',
          score: '9-13'
        },
        {
          id: '3',
          tournamentName: 'Monthly Cup',
          opponent: 'Team Gamma',
          result: 'win',
          date: '2024-01-05T18:00:00Z',
          score: '13-5'
        }
      ];

      setTimeout(() => {
        setUserStats(mockStats);
        setRecentMatches(mockMatches);
        setLoading(false);
      }, 1000);
    };

    fetchDashboardData();
  }, []);

  if (loading) {
    return <div className="loading">Loading dashboard...</div>;
  }

  if (!userStats) {
    return <div className="error">Failed to load dashboard data</div>;
  }

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1>Dashboard</h1>
        <p>Welcome back! Here's your gaming overview.</p>
      </div>

      <div className="dashboard-content">
        <div className="stats-section">
          <h2>Your Stats</h2>
          <div className="stats-grid">
            <div className="stat-card">
              <h3>{userStats.totalTournaments}</h3>
              <p>Total Tournaments</p>
            </div>
            <div className="stat-card">
              <h3>{userStats.wins}</h3>
              <p>Wins</p>
            </div>
            <div className="stat-card">
              <h3>{userStats.losses}</h3>
              <p>Losses</p>
            </div>
            <div className="stat-card">
              <h3>{userStats.winRate}%</h3>
              <p>Win Rate</p>
            </div>
            <div className="stat-card">
              <h3>{userStats.currentRank}</h3>
              <p>Current Rank</p>
            </div>
            <div className="stat-card">
              <h3>${userStats.totalEarnings.toLocaleString()}</h3>
              <p>Total Earnings</p>
            </div>
          </div>
        </div>

        <div className="recent-matches-section">
          <h2>Recent Matches</h2>
          <div className="matches-list">
            {recentMatches.map(match => (
              <div key={match.id} className={`match-card ${match.result}`}>
                <div className="match-info">
                  <h4>{match.tournamentName}</h4>
                  <p>vs {match.opponent}</p>
                  <p className="match-date">{new Date(match.date).toLocaleDateString()}</p>
                </div>
                <div className="match-result">
                  <span className={`result ${match.result}`}>
                    {match.result.toUpperCase()}
                  </span>
                  {match.score && <span className="score">{match.score}</span>}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="upcoming-tournaments-section">
          <h2>Upcoming Tournaments</h2>
          <div className="tournaments-preview">
            <p>You have no registered tournaments yet.</p>
            <button className="btn btn-primary">Browse Tournaments</button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
