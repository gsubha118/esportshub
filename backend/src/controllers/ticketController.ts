import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { TicketModel, Ticket } from '../models/eventModel';
import { EventModel } from '../models/eventModel';

export const joinEvent = async (req: AuthRequest, res: Response) => {
  try {
    const { id: eventId } = req.params;

    if (!eventId) {
      return res.status(400).json({ error: 'Event ID is required' });
    }

    // Check if event exists
    const event = await EventModel.findById(eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    // Check if event is accepting registrations
    if (event.status !== 'published') {
      return res.status(400).json({ error: 'Event is not accepting registrations' });
    }

    // Check if event is full
    if (event.max_teams && event.current_teams >= event.max_teams) {
      return res.status(400).json({ error: 'Event is full' });
    }

    // Check if user already has a ticket for this event
    const existingTicket = await TicketModel.findByEventAndUser(eventId, req.user.id);
    if (existingTicket) {
      return res.status(400).json({ error: 'You are already registered for this event' });
    }

    // Create ticket with pending status
    const ticketData: Omit<Ticket, 'id' | 'purchased_at'> = {
      event_id: eventId,
      user_id: req.user.id,
      status: 'pending',
      external_payment_ref: `pending_${Date.now()}_${req.user.id}`, // Placeholder for external payment reference
      amount: event.organizer_checkout_url ? 25.00 : undefined // Example fee
    };

    const ticket = await TicketModel.create(ticketData);

    res.status(201).json({
      message: 'Successfully registered for event',
      ticket: {
        id: ticket.id,
        event_id: ticket.event_id,
        status: ticket.status,
        external_payment_ref: ticket.external_payment_ref,
        amount: ticket.amount,
        purchased_at: ticket.purchased_at
      }
    });
  } catch (error) {
    console.error('Error joining event:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getUserTickets = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.query.userId as string;

    // If userId query param is provided, check if user is admin or the user themselves
    if (userId && userId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Not authorized to view other users tickets' });
    }

    const targetUserId = userId || req.user.id;
    const tickets = await TicketModel.findByUserId(targetUserId);

    res.json({ tickets });
  } catch (error) {
    console.error('Error fetching user tickets:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
