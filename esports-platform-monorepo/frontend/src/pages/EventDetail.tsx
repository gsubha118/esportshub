import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useEvent } from '../hooks/useEvent';
import { EventService } from '../services/eventService';
import { useAuth } from '../hooks/useAuth';

interface Ticket {
  id: string;
  event_id: string;
  user_id: string;
  status: 'pending' | 'paid' | 'cancelled' | 'refunded';
  external_payment_ref?: string;
  amount?: number;
  purchased_at: string;
  paid_at?: string;
}

const EventDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const { event, loading, error, refetch } = useEvent(id);
  const { isAuthenticated, user } = useAuth();

  const [joining, setJoining] = useState(false);
  const [joinError, setJoinError] = useState<string | null>(null);
  const [showPaymentModal, setShowPaymentModal] = useState(false);

  const handleJoinEvent = async () => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }

    if (!event) return;

    try {
      setJoining(true);
      setJoinError(null);

      // Call backend to join
      await EventService.joinEvent(event.id);

      // Refresh event info
      await refetch();

      // Trigger payment modal if applicable
      if (event.organizer_checkout_url) {
        setShowPaymentModal(true);
      }
    } catch (err) {
      console.error('Error joining event:', err);
      setJoinError(err instanceof Error ? err.message : 'Failed to join event');
    } finally {
      setJoining(false);
    }
  };

  const handlePaymentRedirect = () => {
    if (event?.organizer_checkout_url) {
      window.open(event.organizer_checkout_url, '_blank');
      setShowPaymentModal(false);
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'published':
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
    return (
      <div className="event-detail">
        <div className="loading">Loading event details...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="event-detail">
        <div className="error">
          <h2>Error Loading Event</h2>
          <p>{error}</p>
          <button onClick={refetch} className="btn btn-primary">
            Try Again
          </button>
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="event-detail">
        <div className="error">
          <h2>Event Not Found</h2>
          <p>The requested event could not be found.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="event-detail">
      <div className="event-header">
        <h1>{event.title}</h1>
        <div className="event-meta">
          <span className={`status ${getStatusColor(event.status)}`}>
            {event.status.charAt(0).toUpperCase() + event.status.slice(1)}
          </span>
          {event.game && <span className="game">{event.game}</span>}
        </div>
      </div>

      <div className="event-content">
        <div className="event-info">
          <div className="info-section">
            <h3>Event Information</h3>
            <p><strong>Start Time:</strong> {formatDate(event.start_time)}</p>
            <p><strong>End Time:</strong> {formatDate(event.end_time)}</p>
            <p><strong>Teams:</strong> {event.current_teams}{event.max_teams ? `/${event.max_teams}` : ''}</p>
            <p><strong>Format:</strong> {event.bracket_type.replace('_', ' ').toUpperCase()}</p>
            {event.organizer_checkout_url && (
              <p><strong>Entry Fee:</strong> ${25.00}</p>
            )}
          </div>

          {event.description && (
            <div className="description-section">
              <h3>Description</h3>
              <p>{event.description}</p>
            </div>
          )}

          <div className="bracket-section">
            <h3>Bracket</h3>
            <div className="bracket-placeholder">
              <p>🏆 Tournament bracket will be displayed here</p>
              <p>Bracket visualization coming soon...</p>
            </div>
          </div>
        </div>

        <div className="event-actions">
          {event.status === 'published' && (
            <>
              <button
                className="btn btn-primary"
                onClick={handleJoinEvent}
                disabled={joining}
              >
                {joining ? 'Joining...' : 'Join Event'}
              </button>

              {event.organizer_checkout_url && (
                <button
                  className="btn btn-secondary"
                  onClick={() => window.open(event.organizer_checkout_url, '_blank')}
                >
                  Pay Entry Fee
                </button>
              )}

              {joinError && (
                <p className="error-message">{joinError}</p>
              )}
            </>
          )}

          {event.status === 'live' && (
            <button className="btn btn-secondary">Watch Live</button>
          )}

          <button className="btn btn-outline" onClick={() => navigate('/events')}>
            Back to Events
          </button>
        </div>
      </div>

      {/* Payment Modal */}
      {showPaymentModal && (
        <div className="modal-overlay" onClick={() => setShowPaymentModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Complete Payment</h3>
              <button className="close-btn" onClick={() => setShowPaymentModal(false)}>
                ×
              </button>
            </div>
            <div className="modal-body">
              <p>You have successfully registered for this event!</p>
              <p>To complete your registration, please complete the payment:</p>
              <div className="payment-info">
                <p><strong>Amount:</strong> ${25.00}</p>
                <p><strong>Payment Method:</strong> External Payment Processor</p>
              </div>
              <div className="modal-actions">
                <button className="btn btn-primary" onClick={handlePaymentRedirect}>
                  Pay Now
                </button>
                <button className="btn btn-outline" onClick={() => setShowPaymentModal(false)}>
                  Pay Later
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default EventDetail;
