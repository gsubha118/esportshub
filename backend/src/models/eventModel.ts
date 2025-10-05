import { query, transaction } from '../utils/database';

export interface Event {
  id: string;
  organizer_id: string;
  title: string;
  description?: string;
  game: string;
  start_time: Date;
  end_time: Date;
  bracket_type: 'single_elimination' | 'double_elimination' | 'round_robin' | 'swiss';
  organizer_checkout_url?: string;
  max_teams?: number;
  current_teams: number;
  status: 'draft' | 'published' | 'live' | 'completed' | 'cancelled';
  created_at: Date;
  updated_at: Date;
}

export interface Ticket {
  id: string;
  event_id: string;
  user_id: string;
  status: 'pending' | 'paid' | 'cancelled' | 'refunded';
  external_payment_ref?: string;
  amount?: number;
  purchased_at: Date;
  paid_at?: Date;
}

export interface Match {
  id: string;
  event_id: string;
  round: number;
  match_number: number;
  player1_id?: string;
  player2_id?: string;
  player1_score?: number;
  player2_score?: number;
  winner_id?: string;
  status: 'pending' | 'in_progress' | 'completed';
  scheduled_time?: Date;
  completed_at?: Date;
}

export class MatchModel {
  static async findByEvent(eventId: string): Promise<Match[]> {
    const result = await query(
      `
      SELECT * FROM matches
      WHERE event_id = $1
      ORDER BY round ASC, match_number ASC
      `,
      [eventId]
    );
    return result.rows;
  }

  static async create(matchData: Omit<Match, 'id'>): Promise<Match> {
    const result = await query(
      `
      INSERT INTO matches (
        event_id, round, match_number, player1_id, player2_id,
        player1_score, player2_score, winner_id, status, scheduled_time
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
      RETURNING *
      `,
      [
        matchData.event_id,
        matchData.round,
        matchData.match_number,
        matchData.player1_id ?? null,
        matchData.player2_id ?? null,
        matchData.player1_score ?? null,
        matchData.player2_score ?? null,
        matchData.winner_id ?? null,
        matchData.status,
        matchData.scheduled_time ?? null
      ]
    );

    return result.rows[0];
  }

  static async deleteByEvent(eventId: string): Promise<void> {
    await query('DELETE FROM matches WHERE event_id = $1', [eventId]);
  }

  /**
   * Generates a single-elimination bracket for an event
   * Randomizes players, pairs them, and inserts all matches
   */
  static async generateBracket(eventId: string, playerIds: string[]): Promise<Match[]> {
    if (playerIds.length < 2) {
      throw new Error('At least 2 players required for bracket generation');
    }

    // Clear existing matches before regenerating
    await this.deleteByEvent(eventId);

    const shuffled = [...playerIds].sort(() => Math.random() - 0.5);
    const totalPlayers = shuffled.length;
    const totalRounds = Math.ceil(Math.log2(totalPlayers));

    let matches: Match[] = [];
    let roundPlayers = [...shuffled];
    let matchNumber = 1;

    await transaction(async (client) => {
      for (let round = 1; round <= totalRounds; round++) {
        const roundMatches: Omit<Match, 'id'>[] = [];
        for (let i = 0; i < roundPlayers.length; i += 2) {
          const player1 = roundPlayers[i];
          const player2 = roundPlayers[i + 1];

          const match: Omit<Match, 'id'> = {
            event_id: eventId,
            round,
            match_number: matchNumber++,
            player1_id: player1,
            player2_id: player2,
            status: 'pending'
          };

          roundMatches.push(match);
        }

        // Insert matches in parallel
        const inserted = await Promise.all(
          roundMatches.map((m) =>
            client.query(
              `
              INSERT INTO matches (
                event_id, round, match_number, player1_id, player2_id,
                status
              ) VALUES ($1,$2,$3,$4,$5,$6)
              RETURNING *
              `,
              [
                m.event_id,
                m.round,
                m.match_number,
                m.player1_id ?? null,
        m.player2_id ?? null,
                m.status
              ]
            )
          )
        );

        matches.push(...inserted.map(result => result.rows[0]));

        // Prepare for next round if there are remaining matches
        if (round < totalRounds) {
          roundPlayers = []; // Will be populated with actual winners in a real implementation
        }
      }
    });

    return matches;
  }
}

export class EventModel {
  static async findAll(): Promise<Event[]> {
    const result = await query('SELECT * FROM events WHERE status != $1 ORDER BY created_at DESC', ['draft']);
    return result.rows;
  }

  static async findById(id: string): Promise<Event | null> {
    const result = await query('SELECT * FROM events WHERE id = $1', [id]);
    return result.rows[0] || null;
  }

  static async create(eventData: Omit<Event, 'id' | 'current_teams' | 'created_at' | 'updated_at'>): Promise<Event> {
    const result = await query(
      `
      INSERT INTO events (
        organizer_id, title, description, game, start_time, end_time, 
        bracket_type, organizer_checkout_url, max_teams, status
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING *
      `,
      [
        eventData.organizer_id,
        eventData.title,
        eventData.description || null,
        eventData.game,
        eventData.start_time,
        eventData.end_time,
        eventData.bracket_type,
        eventData.organizer_checkout_url || null,
        eventData.max_teams || null,
        eventData.status
      ]
    );
    return result.rows[0];
  }

  static async findByOrganizer(organizerId: string): Promise<Event[]> {
    const result = await query(
      'SELECT * FROM events WHERE organizer_id = $1 ORDER BY created_at DESC',
      [organizerId]
    );
    return result.rows;
  }

  static async update(id: string, updates: Partial<Event>): Promise<Event | null> {
    const fields = Object.keys(updates);
    const values = Object.values(updates);

    if (fields.length === 0) {
      return this.findById(id);
    }

    const setClause = fields.map((field, index) => `${field} = $${index + 1}`).join(', ');
    const result = await query(
      `UPDATE events SET ${setClause} WHERE id = $${fields.length + 1} RETURNING *`,
      [...values, id]
    );
    return result.rows[0] || null;
  }

  static async delete(id: string): Promise<boolean> {
    const result = await query('DELETE FROM events WHERE id = $1', [id]);
    return result.rowCount > 0;
  }
}

export class TicketModel {
  static async findByEventAndUser(eventId: string, userId: string): Promise<Ticket | null> {
    const result = await query(
      'SELECT * FROM tickets WHERE event_id = $1 AND user_id = $2',
      [eventId, userId]
    );
    return result.rows[0] || null;
  }

  static async findByUserId(userId: string): Promise<Ticket[]> {
    const result = await query(
      `
      SELECT t.*, e.title as event_title, e.game 
      FROM tickets t 
      JOIN events e ON t.event_id = e.id 
      WHERE t.user_id = $1
      ORDER BY t.purchased_at DESC
      `,
      [userId]
    );
    return result.rows;
  }

  static async findByPaymentRef(paymentRef: string): Promise<Ticket | null> {
    const result = await query(
      'SELECT * FROM tickets WHERE external_payment_ref = $1',
      [paymentRef]
    );
    return result.rows[0] || null;
  }

  static async create(ticketData: Omit<Ticket, 'id' | 'purchased_at'>): Promise<Ticket> {
    const result = await query(
      `
      INSERT INTO tickets (
        event_id, user_id, status, external_payment_ref, amount
      )
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
      `,
      [
        ticketData.event_id,
        ticketData.user_id,
        ticketData.status,
        ticketData.external_payment_ref || null,
        ticketData.amount || null
      ]
    );
    return result.rows[0];
  }

  static async updateStatus(ticketId: string, status: string, paidAt?: Date): Promise<Ticket | null> {
    const result = await query(
      `
      UPDATE tickets 
      SET status = $2, paid_at = $3, updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
      RETURNING *
      `,
      [ticketId, status, paidAt || null]
    );
    return result.rows[0] || null;
  }

  static async getParticipantCount(eventId: string): Promise<number> {
    const result = await query(
      'SELECT COUNT(*) as count FROM tickets WHERE event_id = $1 AND status = $2',
      [eventId, 'paid']
    );
    return parseInt(result.rows[0].count) || 0;
  }

  static async getRecentTickets(eventId: string, limit: number = 5): Promise<any[]> {
    const result = await query(
      `
      SELECT id, user_id, status, purchased_at, paid_at
      FROM tickets 
      WHERE event_id = $1 
      ORDER BY purchased_at DESC 
      LIMIT $2
      `,
      [eventId, limit]
    );
    return result.rows;
  }

  static async getTicketsByEvent(eventId: string): Promise<Ticket[]> {
    const result = await query(
      'SELECT * FROM tickets WHERE event_id = $1 ORDER BY purchased_at DESC',
      [eventId]
    );
    return result.rows;
  }
}
