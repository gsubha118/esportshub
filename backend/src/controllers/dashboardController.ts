import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { EventModel, TicketModel } from '../models/eventModel';
import { UserModel } from '../models/userModel';

export interface DashboardData {
  organizer: {
    id: string;
    email: string;
    role: string;
  };
  events: {
    id: string;
    title: string;
    game: string;
    status: string;
    start_time: Date;
    end_time: Date;
    current_teams: number;
    max_teams?: number;
    participant_count: number;
    recent_tickets: {
      id: string;
      user_id: string;
      status: string;
      purchased_at: Date;
      paid_at?: Date;
    }[];
  }[];
  summary: {
    total_events: number;
    total_participants: number;
    active_events: number;
    completed_events: number;
  };
}

export const getOrganizerDashboard = async (req: AuthRequest, res: Response) => {
  try {
    const organizerId = req.user.id;

    // Verify user is an organizer
    const organizer = await UserModel.findById(organizerId);
    if (!organizer || organizer.role !== 'organizer') {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Access denied. Organizer role required.'
      });
    }

    // Get organizer's events with participant counts
    const events = await EventModel.findByOrganizer(organizerId);

    // For each event, get participant count and recent tickets
    const eventsWithStats = await Promise.all(
      events.map(async (event) => {
        const participantCount = await TicketModel.getParticipantCount(event.id);
        const recentTickets = await TicketModel.getRecentTickets(event.id, 5);

        return {
          id: event.id,
          title: event.title,
          game: event.game,
          status: event.status,
          start_time: event.start_time,
          end_time: event.end_time,
          current_teams: event.current_teams,
          max_teams: event.max_teams,
          participant_count: participantCount,
          recent_tickets: recentTickets
        };
      })
    );

    // Calculate summary statistics
    const summary = {
      total_events: events.length,
      total_participants: eventsWithStats.reduce((sum, event) => sum + event.participant_count, 0),
      active_events: eventsWithStats.filter(event => event.status === 'published' || event.status === 'live').length,
      completed_events: eventsWithStats.filter(event => event.status === 'completed').length
    };

    const dashboardData: DashboardData = {
      organizer: {
        id: organizer.id,
        email: organizer.email,
        role: organizer.role
      },
      events: eventsWithStats,
      summary
    };

    res.json(dashboardData);

  } catch (error) {
    console.error('Dashboard error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to load dashboard data'
    });
  }
};
