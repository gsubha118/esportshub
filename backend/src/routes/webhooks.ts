import express from 'express';
import { handlePaymentWebhook } from '../controllers/webhookController';

const router = express.Router();

// Webhook routes (no auth middleware - external services)
router.post('/payment', handlePaymentWebhook);

export default router;
