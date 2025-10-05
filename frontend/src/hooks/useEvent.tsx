import { useState, useEffect } from 'react';
import { EventService, Event } from '../services/eventService';

export interface UseEventResult {
  event: Event | null;
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export const useEvent = (id: string | undefined): UseEventResult => {
  const [event, setEvent] = useState<Event | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchEvent = async () => {
    if (!id) {
      setLoading(false);
      setError('Event ID is required');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const fetchedEvent = await EventService.getEventById(id);
      setEvent(fetchedEvent);
    } catch (err) {
      console.error('Error fetching event:', err);
      setError(err instanceof Error ? err.message : 'Failed to fetch event');
      setEvent(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEvent();
  }, [id]);

  return {
    event,
    loading,
    error,
    refetch: fetchEvent
  };
};
