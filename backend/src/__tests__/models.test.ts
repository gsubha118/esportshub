import { jest } from '@jest/globals';
import { EventModel, TicketModel } from '../models/eventModel';
import { query } from '../utils/database';

// Mock the database module
jest.mock('../utils/database', () => ({
  query: jest.fn(),
}));

describe('EventModel', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findAll', () => {
    it('should return all published and live events', async () => {
      const mockEvents = [
        { id: '1', title: 'Event 1', status: 'published' },
        { id: '2', title: 'Event 2', status: 'live' }
      ];

      (query as jest.Mock).mockResolvedValue({ rows: mockEvents });

      const result = await EventModel.findAll();

      expect(result).toEqual(mockEvents);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT * FROM events'),
        expect.any(Array)
      );
    });
  });

  describe('findById', () => {
    it('should return event by id', async () => {
      const mockEvent = { id: '1', title: 'Test Event' };
      (query as jest.Mock).mockResolvedValue({ rows: [mockEvent] });

      const result = await EventModel.findById('1');

      expect(result).toEqual(mockEvent);
      expect(query).toHaveBeenCalledWith(
        'SELECT * FROM events WHERE id = $1',
        ['1']
      );
    });

    it('should return null for non-existent event', async () => {
      (query as jest.Mock).mockResolvedValue({ rows: [] });

      const result = await EventModel.findById('999');

      expect(result).toBeNull();
    });
  });

  describe('create', () => {
    it('should create a new event', async () => {
      const eventData = {
        organizer_id: 'user-1',
        title: 'New Event',
        description: 'Test description',
        game: 'Valorant',
        start_time: new Date(),
        end_time: new Date(),
        bracket_type: 'single_elimination' as const,
        organizer_checkout_url: 'https://example.com',
        max_teams: 16,
        status: 'published' as const
      };

      const createdEvent = { id: '3', ...eventData };
      (query as jest.Mock).mockResolvedValue({ rows: [createdEvent] });

      const result = await EventModel.create(eventData);

      expect(result).toEqual(createdEvent);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO events'),
        expect.arrayContaining([
          eventData.organizer_id,
          eventData.title,
          eventData.description,
          eventData.game,
          eventData.start_time,
          eventData.end_time,
          eventData.bracket_type,
          eventData.organizer_checkout_url,
          eventData.max_teams,
          eventData.status
        ])
      );
    });
  });

  describe('update', () => {
    it('should update an existing event', async () => {
      const updates = { title: 'Updated Event Title' };
      const updatedEvent = { id: '1', title: 'Updated Event Title' };

      (query as jest.Mock).mockResolvedValue({ rows: [updatedEvent] });

      const result = await EventModel.update('1', updates);

      expect(result).toEqual(updatedEvent);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE events'),
        expect.arrayContaining(['Updated Event Title', '1'])
      );
    });

    it('should return null for non-existent event', async () => {
      (query as jest.Mock).mockResolvedValue({ rows: [] });

      const result = await EventModel.update('999', { title: 'New Title' });

      expect(result).toBeNull();
    });
  });

  describe('delete', () => {
    it('should delete an event', async () => {
      (query as jest.Mock).mockResolvedValue({ rowCount: 1 });

      const result = await EventModel.delete('1');

      expect(result).toBe(true);
      expect(query).toHaveBeenCalledWith('DELETE FROM events WHERE id = $1', ['1']);
    });

    it('should return false for non-existent event', async () => {
      (query as jest.Mock).mockResolvedValue({ rowCount: 0 });

      const result = await EventModel.delete('999');

      expect(result).toBe(false);
    });
  });
});

describe('TicketModel', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findByUserId', () => {
    it('should return user tickets with event details', async () => {
      const mockTickets = [
        {
          id: '1',
          event_id: 'event-1',
          user_id: 'user-1',
          status: 'paid',
          purchased_at: new Date(),
          event_title: 'Event 1',
          game: 'Valorant'
        }
      ];

      (query as jest.Mock).mockResolvedValue({ rows: mockTickets });

      const result = await TicketModel.findByUserId('user-1');

      expect(result).toEqual(mockTickets);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT t.*, e.title as event_title, e.game'),
        ['user-1']
      );
    });
  });

  describe('findByEventAndUser', () => {
    it('should return ticket for specific event and user', async () => {
      const mockTicket = { id: '1', event_id: 'event-1', user_id: 'user-1' };
      (query as jest.Mock).mockResolvedValue({ rows: [mockTicket] });

      const result = await TicketModel.findByEventAndUser('event-1', 'user-1');

      expect(result).toEqual(mockTicket);
      expect(query).toHaveBeenCalledWith(
        'SELECT * FROM tickets WHERE event_id = $1 AND user_id = $2',
        ['event-1', 'user-1']
      );
    });

    it('should return null if no ticket found', async () => {
      (query as jest.Mock).mockResolvedValue({ rows: [] });

      const result = await TicketModel.findByEventAndUser('event-1', 'user-1');

      expect(result).toBeNull();
    });
  });

  describe('create', () => {
    it('should create a new ticket', async () => {
      const ticketData = {
        event_id: 'event-1',
        user_id: 'user-1',
        status: 'pending' as const,
        external_payment_ref: 'payment-ref-123',
        amount: 25.00
      };

      const createdTicket = { id: 'ticket-1', ...ticketData };
      (query as jest.Mock).mockResolvedValue({ rows: [createdTicket] });

      const result = await TicketModel.create(ticketData);

      expect(result).toEqual(createdTicket);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO tickets'),
        expect.arrayContaining([
          ticketData.event_id,
          ticketData.user_id,
          ticketData.status,
          ticketData.external_payment_ref,
          ticketData.amount
        ])
      );
    });
  });

  describe('updateStatus', () => {
    it('should update ticket status', async () => {
      const updatedTicket = {
        id: 'ticket-1',
        status: 'paid',
        paid_at: new Date()
      };

      (query as jest.Mock).mockResolvedValue({ rows: [updatedTicket] });

      const result = await TicketModel.updateStatus('ticket-1', 'paid', new Date());

      expect(result).toEqual(updatedTicket);
      expect(query).toHaveBeenCalledWith(
        'UPDATE tickets SET status = $1, paid_at = $2 WHERE id = $3',
        ['paid', expect.any(Date), 'ticket-1']
      );
    });

    it('should return null for non-existent ticket', async () => {
      (query as jest.Mock).mockResolvedValue({ rows: [] });

      const result = await TicketModel.updateStatus('non-existent', 'paid');

      expect(result).toBeNull();
    });
  });

  describe('findByPaymentRef', () => {
    it('should return ticket by payment reference', async () => {
      const mockTicket = { id: '1', event_id: 'event-1', external_payment_ref: 'payment-ref-123' };
      (query as jest.Mock).mockResolvedValue({ rows: [mockTicket] });

      const result = await TicketModel.findByPaymentRef('payment-ref-123');

      expect(result).toEqual(mockTicket);
      expect(query).toHaveBeenCalledWith(
        'SELECT * FROM tickets WHERE external_payment_ref = $1',
        ['payment-ref-123']
      );
    });

    it('should return null for non-existent payment reference', async () => {
      (query as jest.Mock).mockResolvedValue({ rows: [] });

      const result = await TicketModel.findByPaymentRef('non-existent');

      expect(result).toBeNull();
    });
  });
  describe('getTicketsByEvent', () => {
    it('should return all tickets for an event', async () => {
      const mockTickets = [
        { id: '1', event_id: 'event-1', status: 'paid' },
        { id: '2', event_id: 'event-1', status: 'pending' }
      ];

      (query as jest.Mock).mockResolvedValue({ rows: mockTickets });

      const result = await TicketModel.getTicketsByEvent('event-1');

      expect(result).toEqual(mockTickets);
      expect(query).toHaveBeenCalledWith(
        'SELECT * FROM tickets WHERE event_id = $1 ORDER BY purchased_at DESC',
        ['event-1']
      );
    });
  });
});
