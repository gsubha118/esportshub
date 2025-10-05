import request from 'supertest';
import express from 'express';
import { jest } from '@jest/globals';

// Mock the database module
jest.mock('../utils/database', () => ({
  query: jest.fn(),
  transaction: jest.fn(),
}));

// Mock the auth middleware
jest.mock('../middleware/auth', () => ({
  authenticateToken: jest.fn((req, res, next) => {
    req.user = { id: 'test-user-id', role: 'player' };
    next();
  }),
}));

import eventRoutes from '../routes/events';
import ticketRoutes from '../routes/tickets';
import { query } from '../utils/database';

const app = express();
app.use(express.json());
app.use('/api/events', eventRoutes);
app.use('/api/tickets', ticketRoutes);

describe('Event Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /api/events', () => {
    it('should return all events', async () => {
      const mockEvents = [
        {
          id: '1',
          title: 'Test Event 1',
          game: 'Valorant',
          status: 'published',
          start_time: new Date(),
          end_time: new Date(),
          current_teams: 5,
          max_teams: 10,
          bracket_type: 'single_elimination'
        },
        {
          id: '2',
          title: 'Test Event 2',
          game: 'CS:GO',
          status: 'live',
          start_time: new Date(),
          end_time: new Date(),
          current_teams: 8,
          max_teams: 8,
          bracket_type: 'double_elimination'
        }
      ];

      (query as jest.Mock).mockResolvedValue({ rows: mockEvents });

      const response = await request(app)
        .get('/api/events')
        .expect(200);

      expect(response.body).toHaveProperty('events');
      expect(response.body.events).toHaveLength(2);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT * FROM events'),
        expect.any(Array)
      );
    });
  });

  describe('GET /api/events/:id', () => {
    it('should return event by id', async () => {
      const mockEvent = {
        id: '1',
        title: 'Test Event',
        game: 'Valorant',
        status: 'published',
        start_time: new Date(),
        end_time: new Date(),
        current_teams: 5,
        max_teams: 10,
        bracket_type: 'single_elimination'
      };

      (query as jest.Mock).mockResolvedValue({ rows: [mockEvent] });

      const response = await request(app)
        .get('/api/events/1')
        .expect(200);

      expect(response.body).toHaveProperty('event');
      expect(response.body.event.id).toBe('1');
      expect(query).toHaveBeenCalledWith(
        'SELECT * FROM events WHERE id = $1',
        ['1']
      );
    });

    it('should return 404 for non-existent event', async () => {
      (query as jest.Mock).mockResolvedValue({ rows: [] });

      await request(app)
        .get('/api/events/999')
        .expect(404);
    });
  });

  describe('POST /api/events', () => {
    it('should create a new event', async () => {
      const newEvent = {
        title: 'New Tournament',
        description: 'A great tournament',
        game: 'Valorant',
        start_time: new Date(Date.now() + 86400000), // Tomorrow
        end_time: new Date(Date.now() + 172800000), // Day after tomorrow
        bracket_type: 'single_elimination',
        max_teams: 16
      };

      const createdEvent = {
        id: '3',
        ...newEvent,
        organizer_id: 'test-user-id',
        status: 'published',
        current_teams: 0,
        created_at: new Date(),
        updated_at: new Date()
      };

      (query as jest.Mock).mockResolvedValue({ rows: [createdEvent] });

      const response = await request(app)
        .post('/api/events')
        .send(newEvent)
        .expect(201);

      expect(response.body).toHaveProperty('message', 'Event created successfully');
      expect(response.body).toHaveProperty('event');
      expect(response.body.event.title).toBe(newEvent.title);
    });

    it('should return 403 for non-organizer users', async () => {
      // Mock auth middleware to return non-organizer role
      const authMiddleware = require('../middleware/auth').authenticateToken;
      authMiddleware.mockImplementationOnce((req, res, next) => {
        req.user = { id: 'test-user-id', role: 'player' };
        next();
      });

      const newEvent = {
        title: 'New Tournament',
        game: 'Valorant',
        start_time: new Date(Date.now() + 86400000),
        end_time: new Date(Date.now() + 172800000)
      };

      await request(app)
        .post('/api/events')
        .send(newEvent)
        .expect(403);
    });
  });

  describe('POST /api/events/:id/join', () => {
    it('should register user for event', async () => {
      // Mock event exists and is accepting registrations
      (query as jest.Mock)
        .mockResolvedValueOnce({ rows: [{ id: '1', status: 'published', max_teams: 10, current_teams: 5 }] }) // Event query
        .mockResolvedValueOnce({ rows: [] }) // Check existing ticket
        .mockResolvedValueOnce({ rows: [{ id: 'ticket-1' }] }); // Create ticket

      const response = await request(app)
        .post('/api/events/1/join')
        .expect(201);

      expect(response.body).toHaveProperty('message', 'Successfully registered for event');
    });

    it('should return 400 if event is full', async () => {
      // Mock event that is full
      (query as jest.Mock).mockResolvedValueOnce({
        rows: [{ id: '1', status: 'published', max_teams: 10, current_teams: 10 }]
      });

      await request(app)
        .post('/api/events/1/join')
        .expect(400);
    });

    it('should return 400 if already registered', async () => {
      // Mock event exists and user already has ticket
      (query as jest.Mock)
        .mockResolvedValueOnce({ rows: [{ id: '1', status: 'published', max_teams: 10, current_teams: 5 }] }) // Event query
        .mockResolvedValueOnce({ rows: [{ id: 'existing-ticket' }] }); // Check existing ticket

      await request(app)
        .post('/api/events/1/join')
        .expect(400);
    });
  });
});

describe('Ticket Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /api/tickets', () => {
    it('should return user tickets', async () => {
      const mockTickets = [
        {
          id: '1',
          event_id: 'event-1',
          user_id: 'test-user-id',
          status: 'paid',
          purchased_at: new Date(),
          event_title: 'Test Event 1',
          game: 'Valorant'
        },
        {
          id: '2',
          event_id: 'event-2',
          user_id: 'test-user-id',
          status: 'pending',
          purchased_at: new Date(),
          event_title: 'Test Event 2',
          game: 'CS:GO'
        }
      ];

      (query as jest.Mock).mockResolvedValue({ rows: mockTickets });

      const response = await request(app)
        .get('/api/tickets')
        .expect(200);

      expect(response.body).toHaveProperty('tickets');
      expect(response.body.tickets).toHaveLength(2);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT t.*, e.title as event_title, e.game'),
        ['test-user-id']
      );
    });

    it('should return tickets for specific user when userId query param provided', async () => {
      const mockTickets = [
        {
          id: '1',
          event_id: 'event-1',
          user_id: 'other-user-id',
          status: 'paid',
          purchased_at: new Date(),
          event_title: 'Test Event 1',
          game: 'Valorant'
        }
      ];

      (query as jest.Mock).mockResolvedValue({ rows: mockTickets });

      // Mock auth middleware to return admin role for this test
      const authMiddleware = require('../middleware/auth').authenticateToken;
      authMiddleware.mockImplementationOnce((req, res, next) => {
        req.user = { id: 'admin-user-id', role: 'admin' };
        next();
      });

      const response = await request(app)
        .get('/api/tickets?userId=other-user-id')
        .expect(200);

      expect(response.body).toHaveProperty('tickets');
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT t.*, e.title as event_title, e.game'),
        ['other-user-id']
      );
    });
  });
});
