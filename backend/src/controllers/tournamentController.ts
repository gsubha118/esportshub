import { Request, Response } from 'express';
import { AuthRequest } from '../middleware/auth';

// Mock tournament database
let tournaments: any[] = [
  {
    id: '1',
    name: 'Weekly Championship',
    game: 'Valorant',
    prizePool: 10000,
    status: 'upcoming',
    participants: 45,
    maxParticipants: 64,
    startDate: '2024-01-15T18:00:00Z',
    description: 'Join the ultimate Valorant championship where the best teams compete for glory and prizes.',
    rules: [
      'Teams must consist of 5 players',
      'All players must be at least 16 years old',
      'Matches will be played on the latest patch'
    ],
    createdBy: 1,
    participantsList: []
  },
  {
    id: '2',
    name: 'Speedrun Challenge',
    game: 'Any',
    prizePool: 5000,
    status: 'live',
    participants: 23,
    maxParticipants: 50,
    startDate: '2024-01-10T12:00:00Z',
    description: 'Speedrun any game of your choice and compete for the fastest times.',
    rules: [
      'Any game is allowed',
      'Must provide video proof',
      'No cheating or exploits allowed'
    ],
    createdBy: 1,
    participantsList: []
  }
];

export const getAllTournaments = async (req: Request, res: Response) => {
  try {
    const { status, game } = req.query;
    let filteredTournaments = tournaments;

    if (status) {
      filteredTournaments = filteredTournaments.filter(t => t.status === status);
    }

    if (game) {
      filteredTournaments = filteredTournaments.filter(t => t.game.toLowerCase() === (game as string).toLowerCase());
    }

    res.json({ tournaments: filteredTournaments });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getTournamentById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const tournament = tournaments.find(t => t.id === id);

    if (!tournament) {
      return res.status(404).json({ error: 'Tournament not found' });
    }

    res.json({ tournament });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createTournament = async (req: AuthRequest, res: Response) => {
  try {
    const { name, game, prizePool, maxParticipants, startDate, description, rules } = req.body;

    const newTournament = {
      id: (tournaments.length + 1).toString(),
      name,
      game,
      prizePool: parseInt(prizePool),
      status: 'upcoming',
      participants: 0,
      maxParticipants: parseInt(maxParticipants),
      startDate,
      description,
      rules,
      createdBy: req.user.id,
      participantsList: []
    };

    tournaments.push(newTournament);

    res.status(201).json({
      message: 'Tournament created successfully',
      tournament: newTournament
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateTournament = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    const tournamentIndex = tournaments.findIndex(t => t.id === id);

    if (tournamentIndex === -1) {
      return res.status(404).json({ error: 'Tournament not found' });
    }

    // Check if user owns the tournament
    if (tournaments[tournamentIndex].createdBy !== req.user.id) {
      return res.status(403).json({ error: 'Not authorized to update this tournament' });
    }

    tournaments[tournamentIndex] = { ...tournaments[tournamentIndex], ...updates };

    res.json({
      message: 'Tournament updated successfully',
      tournament: tournaments[tournamentIndex]
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteTournament = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const tournamentIndex = tournaments.findIndex(t => t.id === id);

    if (tournamentIndex === -1) {
      return res.status(404).json({ error: 'Tournament not found' });
    }

    // Check if user owns the tournament
    if (tournaments[tournamentIndex].createdBy !== req.user.id) {
      return res.status(403).json({ error: 'Not authorized to delete this tournament' });
    }

    tournaments.splice(tournamentIndex, 1);

    res.json({ message: 'Tournament deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const registerForTournament = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const tournament = tournaments.find(t => t.id === id);

    if (!tournament) {
      return res.status(404).json({ error: 'Tournament not found' });
    }

    if (tournament.participants >= tournament.maxParticipants) {
      return res.status(400).json({ error: 'Tournament is full' });
    }

    if (tournament.participantsList.includes(req.user.id)) {
      return res.status(400).json({ error: 'Already registered for this tournament' });
    }

    tournament.participantsList.push(req.user.id);
    tournament.participants += 1;

    res.json({ message: 'Successfully registered for tournament' });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getTournamentParticipants = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const tournament = tournaments.find(t => t.id === id);

    if (!tournament) {
      return res.status(404).json({ error: 'Tournament not found' });
    }

    // In a real app, you'd fetch actual user data
    res.json({
      participants: tournament.participantsList.map((userId: number) => ({
        id: userId,
        username: `User${userId}`
      }))
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};
