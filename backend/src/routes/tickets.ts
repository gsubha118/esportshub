import express from 'express';
import { joinEvent, getUserTickets } from '../controllers/ticketController';
import { authenticateToken } from '../middleware/auth';

const router = express.Router();

// Protected routes (require authentication)
router.post('/:id/join', authenticateToken, joinEvent);
router.get('/', authenticateToken, getUserTickets);

export default router;
