import express from 'express';
import {
  getAllTournaments,
  getTournamentById,
  createTournament,
  updateTournament,
  deleteTournament,
  registerForTournament,
  getTournamentParticipants
} from '../controllers/tournamentController';
import { authenticateToken } from '../middleware/auth';

const router = express.Router();

// Public routes
router.get('/', getAllTournaments);
router.get('/:id', getTournamentById);
router.get('/:id/participants', getTournamentParticipants);

// Protected routes (require authentication)
router.post('/', authenticateToken, createTournament);
router.put('/:id', authenticateToken, updateTournament);
router.delete('/:id', authenticateToken, deleteTournament);
router.post('/:id/register', authenticateToken, registerForTournament);

export default router;
