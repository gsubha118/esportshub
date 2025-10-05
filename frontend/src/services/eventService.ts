>import { ApiService } from '../utils/api';

export interface Event {
  id: string;
  organizer_id: string;
  title: string;
  description?: string;
  game: string;
  start_time: string;
  end_time: string;
  bracket_type: 'single_elimination' | 'double_elimination' | 'round_robin' | 'swiss';
  organizer_checkout_url?: string;
  max_teams?: number;
  current_teams: number;
  status: 'draft' | 'published' | 'live' | 'completed' | 'cancelled';
  created_at: string;
  updated_at: string;
}

export interface EventResponse {
  events: Event[];
}

export interface Participant {
  id: string;
  event_id: string;
  user_id: string;
  status: 'pending' | 'paid' | 'cancelled' | 'refunded';
  external_payment_ref?: string;
  amount?: number;
  purchased_at: string;
  paid_at?: string;
  event_title?: string;
  game?: string;
}

export interface CreateEventRequest {
  title: string;
  description?: string;
  game: string;
  start_time: string;
  end_time: string;
  bracket_type: 'single_elimination' | 'double_elimination' | 'round_robin' | 'swiss';
  organizer_checkout_url?: string;
  max_teams?: number;
}

export class EventService {
  static async getAllEvents(): Promise<Event[]> {
    try {
      const response = await ApiService.get<EventResponse>('/events');
      return response.events;
    } catch (error) {
      console.error('Failed to fetch events:', error);
      throw error;
    }
  }

  static async getEventById(id: string): Promise<Event> {
    try {
      const response = await ApiService.get<{ event: Event }>(`/events/${id}`);
      return response.event;
    } catch (error) {
      console.error(`Failed to fetch event ${id}:`, error);
      throw error;
    }
  }

  static async createEvent(eventData: CreateEventRequest): Promise<Event> {
    try {
      const response = await ApiService.post<{ event: Event }>('/events', eventData);
      return response.event;
    } catch (error) {
      console.error('Failed to create event:', error);
      throw error;
    }
  }

  static async joinEvent(eventId: string): Promise<{ message: string }> {
    try {
      const response = await ApiService.post<{ message: string }>(`/events/${eventId}/join`);
      return response;
    } catch (error) {
      console.error(`Failed to join event ${eventId}:`, error);
      throw error;
    }
  }

  static async getOrganizerEvents(): Promise<Event[]> {
    try {
      const response = await ApiService.get<EventResponse>('/events?organizer=true');
      return response.events;
    } catch (error) {
      console.error('Failed to fetch organizer events:', error);
      throw error;
    }
  }

  static async getEventParticipants(eventId: string): Promise<Participant[]> {
    try {
      const response = await ApiService.get<{ participants: Participant[] }>(`/events/${eventId}/participants`);
      return response.participants;
    } catch (error) {
      console.error(`Failed to fetch participants for event ${eventId}:`, error);
      throw error;
    }
  }
}
