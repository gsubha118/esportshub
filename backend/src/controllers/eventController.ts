import { Request, Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { EventModel, Event, TicketModel, Ticket } from '../models/eventModel';
import Joi from 'joi';

// Validation schemas
const createEventSchema = Joi.object({
  title: Joi.string().min(5).max(255).required(),
  description: Joi.string().max(1000).optional(),
  game: Joi.string().min(1).max(100).required(),
  start_time: Joi.date().greater('now').required(),
  end_time: Joi.date().greater(Joi.ref('start_time')).required(),
  bracket_type: Joi.string().valid('single_elimination', 'double_elimination', 'round_robin', 'swiss').default('single_elimination'),
  organizer_checkout_url: Joi.string().uri().optional(),
  max_teams: Joi.number().integer().min(2).max(128).optional()
});

export const getAllEvents = async (req: Request, res: Response) => {
  try {
    const events = await EventModel.findAll();
    res.json({ events });
  } catch (error) {
    console.error('Error fetching events:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getEventById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({ error: 'Event ID is required' });
    }

    const event = await EventModel.findById(id);

    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.json({ event });
  } catch (error) {
    console.error('Error fetching event:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createEvent = async (req: AuthRequest, res: Response) => {
  try {
    // Validate request body
    const { error, value } = createEventSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // Check if user is an organizer
    if (req.user.role !== 'organizer' && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Only organizers can create events' });
    }

    const eventData: Omit<Event, 'id' | 'current_teams' | 'created_at' | 'updated_at'> = {
      organizer_id: req.user.id,
      title: value.title,
      description: value.description,
      game: value.game,
      start_time: value.start_time,
      end_time: value.end_time,
      bracket_type: value.bracket_type,
      organizer_checkout_url: value.organizer_checkout_url,
      max_teams: value.max_teams,
      status: 'published' // Events are published by default when created
    };

    const event = await EventModel.create(eventData);

    res.status(201).json({
      message: 'Event created successfully',
      event
    });
  } catch (error) {
    console.error('Error creating event:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateEvent = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    const event = await EventModel.findById(id);

    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    // Check if user owns the event or is admin
    if (event.organizer_id !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Not authorized to update this event' });
    }

    const updatedEvent = await EventModel.update(id, updates);

    res.json({
      message: 'Event updated successfully',
      event: updatedEvent
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteEvent = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const event = await EventModel.findById(id);

    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    // Check if user owns the event or is admin
    if (event.organizer_id !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Not authorized to delete this event' });
    }

    await EventModel.delete(id);

    res.json({ message: 'Event deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const registerForEvent = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const event = await EventModel.findById(id);

    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    if (event.status !== 'published') {
      return res.status(400).json({ error: 'Event is not accepting registrations' });
    }

    if (event.max_teams && event.current_teams >= event.max_teams) {
      return res.status(400).json({ error: 'Event is full' });
    }

    // Check if user already has a ticket for this event
    const existingTicket = await TicketModel.findByEventAndUser(id, req.user.id);
    if (existingTicket) {
      return res.status(400).json({ error: 'You are already registered for this event' });
    }

    // Create ticket with pending status
    const ticketData: Omit<Ticket, 'id' | 'purchased_at'> = {
      event_id: id,
      user_id: req.user.id,
      status: 'pending',
      external_payment_ref: `pending_${Date.now()}_${req.user.id}`, // Placeholder for external payment reference
      amount: event.organizer_checkout_url ? 25.00 : undefined // Example fee
    };

    const ticket = await TicketModel.create(ticketData);

    res.json({ message: 'Successfully registered for event' });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getEventParticipants = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const event = await EventModel.findById(id);

    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const tickets = await TicketModel.getTicketsByEvent(id);

    res.json({
      participants: tickets.map((ticket: Ticket) => ({
        id: ticket.id,
        user_id: ticket.user_id,
        status: ticket.status,
        purchased_at: ticket.purchased_at
      }))
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};
