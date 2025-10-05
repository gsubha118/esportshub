import { Request, Response } from 'express';
import { TicketModel } from '../models/eventModel';

interface PaymentWebhookPayload {
  external_payment_ref: string;
  status: 'completed' | 'failed' | 'cancelled';
  amount?: number;
  currency?: string;
  payment_method?: string;
  metadata?: {
    event_id?: string;
    user_id?: string;
  };
}

export const handlePaymentWebhook = async (req: Request, res: Response) => {
  try {
    // 1. Validate shared secret header
    const webhookSecret = req.headers['x-webhook-secret'] as string;
    const expectedSecret = process.env.PAYMENT_WEBHOOK_SECRET;

    if (!webhookSecret || webhookSecret !== expectedSecret) {
      console.warn('Payment webhook: Invalid or missing webhook secret');
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid webhook secret'
      });
    }

    // 2. Validate request body
    const payload: PaymentWebhookPayload = req.body;

    if (!payload || !payload.external_payment_ref) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Missing external_payment_ref in request body'
      });
    }

    // 3. Find ticket by external_payment_ref
    const ticket = await TicketModel.findByPaymentRef(payload.external_payment_ref);

    if (!ticket) {
      console.warn(`Payment webhook: Ticket not found for payment ref ${payload.external_payment_ref}`);
      return res.status(404).json({
        error: 'Not Found',
        message: 'Ticket not found for the provided payment reference'
      });
    }

    // 4. Validate payment status
    if (payload.status !== 'completed') {
      console.log(`Payment webhook: Payment ${payload.status} for ticket ${ticket.id}`);
      return res.status(200).json({
        message: `Payment status updated to ${payload.status}`,
        ticket_id: ticket.id,
        status: payload.status
      });
    }

    // 5. Update ticket status to paid
    const currentTime = new Date();
    const updatedTicket = await TicketModel.updateStatus(ticket.id, 'paid', currentTime);

    if (!updatedTicket) {
      console.error(`Payment webhook: Failed to update ticket ${ticket.id}`);
      return res.status(500).json({
        error: 'Internal Server Error',
        message: 'Failed to update ticket status'
      });
    }

    // 6. Log successful payment
    console.log(`✅ Payment webhook: Successfully processed payment for ticket ${ticket.id}`, {
      ticket_id: ticket.id,
      event_id: ticket.event_id,
      user_id: ticket.user_id,
      amount: payload.amount,
      currency: payload.currency,
      payment_method: payload.payment_method,
      payment_ref: payload.external_payment_ref,
      processed_at: currentTime.toISOString()
    });

    // 7. Send notification (placeholder - could integrate with email service, Discord, etc.)
    await sendPaymentNotification(updatedTicket, payload);

    // 8. Return success response
    res.status(200).json({
      success: true,
      message: 'Payment processed successfully',
      ticket_id: ticket.id,
      status: 'paid',
      processed_at: currentTime.toISOString()
    });

  } catch (error) {
    console.error('Payment webhook error:', error);

    // Return 500 for server errors, but don't expose internal details
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to process payment webhook'
    });
  }
};

// Helper function to send payment notifications
async function sendPaymentNotification(ticket: any, payload: PaymentWebhookPayload) {
  try {
    // This is a placeholder for notification logic
    // In a real application, you might:
    // - Send email confirmation to user
    // - Send Discord notification
    // - Update external systems
    // - Send push notifications

    const notificationData = {
      type: 'payment_completed',
      ticket_id: ticket.id,
      event_id: ticket.event_id,
      user_id: ticket.user_id,
      amount: payload.amount,
      currency: payload.currency,
      payment_ref: payload.external_payment_ref,
      processed_at: new Date().toISOString()
    };

    // Log notification (in production, send actual notifications)
    console.log('📧 Payment notification would be sent:', notificationData);

    // TODO: Implement actual notification sending
    // await emailService.sendPaymentConfirmation(user.email, notificationData);
    // await discordService.sendNotification(notificationData);

  } catch (notificationError) {
    // Don't fail the webhook if notification fails
    console.error('Failed to send payment notification:', notificationError);
  }
}
