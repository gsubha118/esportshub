import { useState, useEffect } from 'react';
import { EventService, Event } from '../services/eventService';

export interface UseEventsResult {
  events: Event[];
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export const useEvents = (): UseEventsResult => {
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchEvents = async () => {
    try {
      setLoading(true);
      setError(null);
      const fetchedEvents = await EventService.getAllEvents();
      setEvents(fetchedEvents);
    } catch (err) {
      console.error('Error fetching events:', err);
      setError(err instanceof Error ? err.message : 'Failed to fetch events');
      setEvents([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEvents();
  }, []);

  return {
    events,
    loading,
    error,
    refetch: fetchEvents
  };
};
