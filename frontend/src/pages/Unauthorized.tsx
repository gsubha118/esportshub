import React from 'react';
import { Link } from 'react-router-dom';
import { useRBAC } from '../hooks/useRBAC';

const Unauthorized: React.FC = () => {
  const { isAuthenticated, user } = useRBAC();

  return (
    <div className="unauthorized">
      <div className="unauthorized-content">
        <h1>Access Denied</h1>
        <p>You don't have permission to access this page.</p>

        {isAuthenticated ? (
          <div>
            <p>Your current role: <strong>{user?.role}</strong></p>
            <p>
              {user?.role === 'player'
                ? 'Players can join events but cannot create or manage them.'
                : 'Contact an administrator to upgrade your account.'}
            </p>
          </div>
        ) : (
          <p>Please log in to access this feature.</p>
        )}

        <div className="unauthorized-actions">
          {isAuthenticated ? (
            <Link to="/events" className="btn btn-primary">
              Browse Events
            </Link>
          ) : (
            <Link to="/login" className="btn btn-primary">
              Sign In
            </Link>
          )}

          <Link to="/" className="btn btn-outline">
            Go Home
          </Link>
        </div>
      </div>
    </div>
  );
};

export default Unauthorized;
