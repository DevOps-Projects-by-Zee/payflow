const twilio = require('twilio');
const logger = require('../shared/logger');

class SMSService {
  constructor() {
    this.client = twilio(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN
    );
    this.fromNumber = process.env.TWILIO_PHONE_NUMBER;
  }

  async sendTransactionAlert(to, amount, type) {
    const message = type === 'SENT' 
      ? `PayFlow: You sent $${amount}. Transaction ID: ${Date.now()}`
      : `PayFlow: You received $${amount}. Transaction ID: ${Date.now()}`;

    try {
      const result = await this.client.messages.create({
        body: message,
        from: this.fromNumber,
        to
      });

      logger.info('SMS sent successfully', { 
        to,
        sid: result.sid,
        type 
      });

      return result;
    } catch (error) {
      logger.error('SMS sending failed', { 
        error: error.message,
        to 
      });
      throw error;
    }
  }

  async send2FACode(to, code) {
    const message = `Your PayFlow verification code is: ${code}. Valid for 5 minutes.`;

    try {
      const result = await this.client.messages.create({
        body: message,
        from: this.fromNumber,
        to
      });

      logger.info('2FA SMS sent', { to, sid: result.sid });
      return result;
    } catch (error) {
      logger.error('2FA SMS failed', { error: error.message, to });
      throw error;
    }
  }
}

module.exports = SMSService;
