import React from 'react';
import { Link } from 'react-router-dom';

const Header: React.FC = () => {
  return (
    <header className="header">
      <div className="container">
        <div className="header-content">
          <Link to="/" className="logo">
            <h1>Esports Platform</h1>
          </Link>
          
          <nav className="nav">
            <ul className="nav-links">
              <li><Link to="/">Home</Link></li>
              <li><Link to="/events">Tournaments</Link></li>
              <li><Link to="/dashboard">Dashboard</Link></li>
            </ul>
          </nav>

          <div className="header-actions">
            <button className="btn btn-outline">Login</button>
            <button className="btn btn-primary">Sign Up</button>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
