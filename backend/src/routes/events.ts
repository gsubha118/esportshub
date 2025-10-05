import express from 'express';
import { getAllEvents, getEventById, createEvent, registerForEvent, getEventParticipants } from '../controllers/eventController';
import { authenticateToken } from '../middleware/auth';
import { MatchModel } from '../models/eventModel';

const router = express.Router();

// Public routes
router.get('/', getAllEvents);
router.get('/:id', getEventById);
router.get('/:id/participants', getEventParticipants);

// Protected routes (require authentication)
router.post('/', authenticateToken, createEvent);
router.post('/:id/join', authenticateToken, registerForEvent);

// Bracket/Match endpoints
router.post('/:id/matches', authenticateToken, async (req, res) => {
  try {
    // Generate matches for an event
    const eventId = req.params.id;
    const playerIds = ['player1', 'player2', 'player3', 'player4']; // Mock player data for UAT
    
    const matches = await MatchModel.generateBracket(eventId, playerIds);
    
    res.status(201).json({
      message: 'Matches generated successfully',
      matches: matches
    });
  } catch (error) {
    console.error('Error generating matches:', error);
    res.status(500).json({ error: 'Failed to generate matches' });
  }
});

router.get('/:id/matches', authenticateToken, async (req, res) => {
  try {
    // Get all matches for an event
    const eventId = req.params.id;
    const matches = await MatchModel.findByEvent(eventId);
    
    res.json({ matches });
  } catch (error) {
    console.error('Error fetching matches:', error);
    res.status(500).json({ error: 'Failed to fetch matches' });
  }
});

router.get('/:id/bracket', async (req, res) => {
  try {
    // Get bracket structure for an event
    const eventId = req.params.id;
    const matches = await MatchModel.findByEvent(eventId);
    
    // Simple bracket structure for UAT
    res.json({
      event_id: eventId,
      bracket_type: 'single_elimination',
      matches: matches,
      rounds: Math.max(...matches.map(m => m.round)) || 0
    });
  } catch (error) {
    console.error('Error fetching bracket:', error);
    res.status(500).json({ error: 'Failed to fetch bracket' });
  }
});

export default router;
