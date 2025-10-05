import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useEvents } from '../hooks/useEvents';
import { Event } from '../services/eventService';

const Events: React.FC = () => {
  const { events, loading, error, refetch } = useEvents();
  const [filter, setFilter] = useState<'all' | 'upcoming' | 'live' | 'completed'>('all');

  const filteredEvents = events.filter((event: Event) =>
    filter === 'all' || event.status === filter
  );

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'upcoming':
        return 'status-upcoming';
      case 'live':
        return 'status-live';
      case 'completed':
        return 'status-completed';
      default:
        return '';
    }
  };

  if (loading) {
    return <div className="loading">Loading tournaments...</div>;
  }

  if (error) {
    return (
      <div className="error">
        Failed to load tournaments. <button onClick={refetch}>Retry</button>
      </div>
    );
  }

  return (
    <div className="events">
      <div className="events-header">
        <h1>Tournaments</h1>
        <div className="filter-buttons">
          <button
            className={filter === 'all' ? 'active' : ''}
            onClick={() => setFilter('all')}
          >
            All
          </button>
          <button
            className={filter === 'upcoming' ? 'active' : ''}
            onClick={() => setFilter('upcoming')}
          >
            Upcoming
          </button>
          <button
            className={filter === 'live' ? 'active' : ''}
            onClick={() => setFilter('live')}
          >
            Live
          </button>
          <button
            className={filter === 'completed' ? 'active' : ''}
            onClick={() => setFilter('completed')}
          >
            Completed
          </button>
        </div>
      </div>

      <div className="tournaments-grid">
        {filteredEvents.map((event: Event) => (
          <div key={event.id} className="tournament-card">
            <div className="tournament-header">
              <h3>{event.name}</h3>
              <span className={`status ${getStatusColor(event.status)}`}>
                {event.status.charAt(0).toUpperCase() + event.status.slice(1)}
              </span>
            </div>

            <div className="tournament-details">
              <p><strong>Game:</strong> {event.game}</p>
              <p><strong>Prize Pool:</strong> ${event.prizePool.toLocaleString()}</p>
              <p><strong>Participants:</strong> {event.participants}/{event.maxParticipants}</p>
              <p><strong>Start Date:</strong> {new Date(event.startDate).toLocaleDateString()}</p>
            </div>

            <div className="tournament-actions">
              <Link to={`/event/${event.id}`}>
                <button className="btn btn-primary">View Details</button>
              </Link>
              {event.status === 'upcoming' && (
                <button className="btn btn-secondary">Register</button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Events;
