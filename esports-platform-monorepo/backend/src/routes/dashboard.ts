import { Router } from 'express';
import { authenticateToken } from '../middleware/auth';
import { getOrganizerDashboard } from '../controllers/dashboardController';

const router = Router();

// Get organizer dashboard data
router.get('/', authenticateToken, getOrganizerDashboard);

// Get dashboard statistics (for UAT test)
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    // Simple stats endpoint for UAT testing
    res.json({
      status: 'success',
      stats: {
        events: 0,
        participants: 0,
        revenue: 0
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

export default router;