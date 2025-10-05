import React from 'react';

const Home: React.FC = () => {
  return (
    <div className="home">
      <section className="hero">
        <h1>Welcome to Esports Platform</h1>
        <p>Compete in tournaments, track your progress, and connect with the gaming community</p>
        <div className="hero-buttons">
          <button className="btn btn-primary">Browse Tournaments</button>
          <button className="btn btn-secondary">Join Community</button>
        </div>
      </section>

      <section className="featured-tournaments">
        <h2>Featured Tournaments</h2>
        <div className="tournament-grid">
          <div className="tournament-card">
            <h3>Weekly Championship</h3>
            <p>Prize Pool: $10,000</p>
            <p>Game: Valorant</p>
            <button className="btn btn-outline">View Details</button>
          </div>
          <div className="tournament-card">
            <h3>Speedrun Challenge</h3>
            <p>Prize Pool: $5,000</p>
            <p>Game: Any Speedrun</p>
            <button className="btn btn-outline">View Details</button>
          </div>
          <div className="tournament-card">
            <h3>Mobile Legends Cup</h3>
            <p>Prize Pool: $15,000</p>
            <p>Game: Mobile Legends</p>
            <button className="btn btn-outline">View Details</button>
          </div>
        </div>
      </section>
    </div>
  );
};

export default Home;
