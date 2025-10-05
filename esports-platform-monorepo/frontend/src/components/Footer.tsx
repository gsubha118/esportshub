import React from 'react';

const Footer: React.FC = () => {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-content">
          <div className="footer-section">
            <h3>Esports Platform</h3>
            <p>The ultimate destination for competitive gaming</p>
          </div>
          
          <div className="footer-section">
            <h4>Platform</h4>
            <ul>
              <li><a href="/events">Tournaments</a></li>
              <li><a href="/leaderboards">Leaderboards</a></li>
              <li><a href="/streams">Live Streams</a></li>
            </ul>
          </div>
          
          <div className="footer-section">
            <h4>Community</h4>
            <ul>
              <li><a href="/forums">Forums</a></li>
              <li><a href="/discord">Discord</a></li>
              <li><a href="/support">Support</a></li>
            </ul>
          </div>
          
          <div className="footer-section">
            <h4>Legal</h4>
            <ul>
              <li><a href="/privacy">Privacy Policy</a></li>
              <li><a href="/terms">Terms of Service</a></li>
              <li><a href="/contact">Contact</a></li>
            </ul>
          </div>
        </div>
        
        <div className="footer-bottom">
          <p>&copy; 2024 Esports Platform. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
