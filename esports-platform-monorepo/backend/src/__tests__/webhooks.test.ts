import request from 'supertest';
import express from 'express';
import { jest } from '@jest/globals';

// Mock the database module
jest.mock('../utils/database', () => ({
  query: jest.fn(),
}));

// Mock the TicketModel
jest.mock('../models/eventModel', () => ({
  TicketModel: {
    findByPaymentRef: jest.fn(),
    updateStatus: jest.fn(),
  },
}));

import { TicketModel } from '../models/eventModel';
import webhookRoutes from '../routes/webhooks';
import { query } from '../utils/database';

const app = express();
app.use(express.json());
app.use('/api/webhooks', webhookRoutes);

// Mock environment variable
process.env.PAYMENT_WEBHOOK_SECRET = 'test-webhook-secret-123';

describe('Payment Webhook Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /api/webhooks/payment', () => {
    const validPayload = {
      external_payment_ref: 'payment_ref_123',
      status: 'completed',
      amount: 25.00,
      currency: 'USD',
      payment_method: 'stripe',
      metadata: {
        event_id: 'event_123',
        user_id: 'user_123'
      }
    };

    const validHeaders = {
      'x-webhook-secret': 'test-webhook-secret-123'
    };

    it('should successfully process a valid payment webhook', async () => {
      const mockTicket = {
        id: 'ticket_123',
        event_id: 'event_123',
        user_id: 'user_123',
        status: 'pending',
        external_payment_ref: 'payment_ref_123',
        amount: 25.00,
        purchased_at: new Date(),
        paid_at: null
      };

      const updatedTicket = {
        ...mockTicket,
        status: 'paid',
        paid_at: new Date()
      };

      // Mock database calls
      (TicketModel.findByPaymentRef as jest.Mock).mockResolvedValue(mockTicket);
      (TicketModel.updateStatus as jest.Mock).mockResolvedValue(updatedTicket);

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(validPayload)
        .expect(200);

      expect(response.body).toMatchObject({
        success: true,
        message: 'Payment processed successfully',
        ticket_id: 'ticket_123',
        status: 'paid'
      });

      expect(response.body).toHaveProperty('processed_at');

      // Verify database calls
      expect(TicketModel.findByPaymentRef).toHaveBeenCalledWith('payment_ref_123');
      expect(TicketModel.updateStatus).toHaveBeenCalledWith(
        'ticket_123',
        'paid',
        expect.any(Date)
      );
    });

    it('should return 401 for invalid webhook secret', async () => {
      const invalidHeaders = {
        'x-webhook-secret': 'invalid-secret'
      };

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(invalidHeaders)
        .send(validPayload)
        .expect(401);

      expect(response.body).toMatchObject({
        error: 'Unauthorized',
        message: 'Invalid webhook secret'
      });

      // Verify no database calls were made
      expect(TicketModel.findByPaymentRef).not.toHaveBeenCalled();
      expect(TicketModel.updateStatus).not.toHaveBeenCalled();
    });

    it('should return 401 for missing webhook secret', async () => {
      const response = await request(app)
        .post('/api/webhooks/payment')
        .send(validPayload)
        .expect(401);

      expect(response.body).toMatchObject({
        error: 'Unauthorized',
        message: 'Invalid webhook secret'
      });

      expect(TicketModel.findByPaymentRef).not.toHaveBeenCalled();
    });

    it('should return 400 for missing external_payment_ref', async () => {
      const invalidPayload = {
        status: 'completed',
        amount: 25.00
      };

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(invalidPayload)
        .expect(400);

      expect(response.body).toMatchObject({
        error: 'Bad Request',
        message: 'Missing external_payment_ref in request body'
      });

      expect(TicketModel.findByPaymentRef).not.toHaveBeenCalled();
    });

    it('should return 404 for non-existent ticket', async () => {
      (TicketModel.findByPaymentRef as jest.Mock).mockResolvedValue(null);

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(validPayload)
        .expect(404);

      expect(response.body).toMatchObject({
        error: 'Not Found',
        message: 'Ticket not found for the provided payment reference'
      });

      expect(TicketModel.findByPaymentRef).toHaveBeenCalledWith('payment_ref_123');
      expect(TicketModel.updateStatus).not.toHaveBeenCalled();
    });

    it('should handle non-completed payment status gracefully', async () => {
      const mockTicket = {
        id: 'ticket_123',
        event_id: 'event_123',
        user_id: 'user_123',
        status: 'pending',
        external_payment_ref: 'payment_ref_123',
        purchased_at: new Date()
      };

      const failedPayload = {
        ...validPayload,
        status: 'failed'
      };

      (TicketModel.findByPaymentRef as jest.Mock).mockResolvedValue(mockTicket);

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(failedPayload)
        .expect(200);

      expect(response.body).toMatchObject({
        message: 'Payment status updated to failed',
        ticket_id: 'ticket_123',
        status: 'failed'
      });

      // Verify ticket status was NOT updated for non-completed payments
      expect(TicketModel.updateStatus).not.toHaveBeenCalled();
    });

    it('should return 500 when ticket update fails', async () => {
      const mockTicket = {
        id: 'ticket_123',
        event_id: 'event_123',
        user_id: 'user_123',
        status: 'pending',
        external_payment_ref: 'payment_ref_123',
        purchased_at: new Date()
      };

      (TicketModel.findByPaymentRef as jest.Mock).mockResolvedValue(mockTicket);
      (TicketModel.updateStatus as jest.Mock).mockResolvedValue(null); // Simulate update failure

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(validPayload)
        .expect(500);

      expect(response.body).toMatchObject({
        error: 'Internal Server Error',
        message: 'Failed to update ticket status'
      });
    });

    it('should handle cancelled payment status', async () => {
      const mockTicket = {
        id: 'ticket_123',
        event_id: 'event_123',
        user_id: 'user_123',
        status: 'pending',
        external_payment_ref: 'payment_ref_123',
        purchased_at: new Date()
      };

      const cancelledPayload = {
        ...validPayload,
        status: 'cancelled'
      };

      (TicketModel.findByPaymentRef as jest.Mock).mockResolvedValue(mockTicket);

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(cancelledPayload)
        .expect(200);

      expect(response.body).toMatchObject({
        message: 'Payment status updated to cancelled',
        ticket_id: 'ticket_123',
        status: 'cancelled'
      });

      expect(TicketModel.updateStatus).not.toHaveBeenCalled();
    });

    it('should handle database errors gracefully', async () => {
      (TicketModel.findByPaymentRef as jest.Mock).mockRejectedValue(new Error('Database connection failed'));

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(validPayload)
        .expect(500);

      expect(response.body).toMatchObject({
        error: 'Internal Server Error',
        message: 'Failed to process payment webhook'
      });
    });

    it('should accept webhook with minimal payload', async () => {
      const minimalPayload = {
        external_payment_ref: 'payment_ref_456',
        status: 'completed'
      };

      const mockTicket = {
        id: 'ticket_456',
        event_id: 'event_456',
        user_id: 'user_456',
        status: 'pending',
        external_payment_ref: 'payment_ref_456',
        purchased_at: new Date()
      };

      const updatedTicket = {
        ...mockTicket,
        status: 'paid',
        paid_at: new Date()
      };

      (TicketModel.findByPaymentRef as jest.Mock).mockResolvedValue(mockTicket);
      (TicketModel.updateStatus as jest.Mock).mockResolvedValue(updatedTicket);

      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send(minimalPayload)
        .expect(200);

      expect(response.body).toMatchObject({
        success: true,
        message: 'Payment processed successfully',
        ticket_id: 'ticket_456',
        status: 'paid'
      });

      expect(TicketModel.findByPaymentRef).toHaveBeenCalledWith('payment_ref_456');
      expect(TicketModel.updateStatus).toHaveBeenCalledWith(
        'ticket_456',
        'paid',
        expect.any(Date)
      );
    });

    it('should handle empty request body', async () => {
      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .send({})
        .expect(400);

      expect(response.body).toMatchObject({
        error: 'Bad Request',
        message: 'Missing external_payment_ref in request body'
      });

      expect(TicketModel.findByPaymentRef).not.toHaveBeenCalled();
    });

    it('should handle malformed JSON', async () => {
      const response = await request(app)
        .post('/api/webhooks/payment')
        .set(validHeaders)
        .set('Content-Type', 'application/json')
        .send('{ invalid json }')
        .expect(400);

      // Express will handle malformed JSON before it reaches our handler
      expect(response.body).toHaveProperty('error');
    });
  });
});
