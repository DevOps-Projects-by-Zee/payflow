const nodemailer = require('nodemailer');
const logger = require('../shared/logger');

class EmailService {
  constructor() {
    this.transporter = nodemailer.createTransporter({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: process.env.SMTP_PORT || 587,
      secure: false, // true for 465, false for other ports
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD
      }
    });

    // For production, use services like:
    // - SendGrid: https://sendgrid.com
    // - AWS SES: https://aws.amazon.com/ses/
    // - Mailgun: https://www.mailgun.com
  }

  async sendTransactionNotification(to, transactionData) {
    const { type, amount, otherParty, transactionId } = transactionData;

    let subject, html;

    if (type === 'SENT') {
      subject = `Payment Sent: $${amount}`;
      html = `
        <h2>Payment Sent Successfully</h2>
        <p>You have sent <strong>$${amount}</strong> to ${otherParty}.</p>
        <p>Transaction ID: ${transactionId}</p>
        <p>Date: ${new Date().toLocaleString()}</p>
        <hr>
        <p style="color: #666; font-size: 12px;">
          If you did not authorize this transaction, please contact support immediately.
        </p>
      `;
    } else if (type === 'RECEIVED') {
      subject = `Payment Received: $${amount}`;
      html = `
        <h2>Payment Received</h2>
        <p>You have received <strong>$${amount}</strong> from ${otherParty}.</p>
        <p>Transaction ID: ${transactionId}</p>
        <p>Date: ${new Date().toLocaleString()}</p>
      `;
    } else if (type === 'FAILED') {
      subject = `Transaction Failed`;
      html = `
        <h2>Transaction Failed</h2>
        <p>Your transaction of <strong>$${amount}</strong> to ${otherParty} has failed.</p>
        <p>Transaction ID: ${transactionId}</p>
        <p>Reason: ${transactionData.reason}</p>
        <p>Please try again or contact support if the problem persists.</p>
      `;
    }

    try {
      const info = await this.transporter.sendMail({
        from: '"PayFlow" <noreply@payflow.com>',
        to,
        subject,
        html
      });

      logger.info('Email sent successfully', { 
        messageId: info.messageId,
        to,
        type 
      });

      return info;
    } catch (error) {
      logger.error('Email sending failed', { 
        error: error.message,
        to,
        type 
      });
      throw error;
    }
  }

  async sendWelcomeEmail(to, name) {
    const subject = 'Welcome to PayFlow!';
    const html = `
      <h1>Welcome to PayFlow, ${name}!</h1>
      <p>Thank you for joining our digital wallet platform.</p>
      <p>Your account has been created successfully with an initial balance of $1,000.</p>
      <h3>Getting Started:</h3>
      <ul>
        <li>Complete your profile</li>
        <li>Verify your email address</li>
        <li>Enable two-factor authentication for extra security</li>
        <li>Start sending and receiving payments</li>
      </ul>
      <p>If you have any questions, feel free to contact our support team.</p>
      <p>Best regards,<br>The PayFlow Team</p>
    `;

    try {
      const info = await this.transporter.sendMail({
        from: '"PayFlow" <welcome@payflow.com>',
        to,
        subject,
        html
      });

      logger.info('Welcome email sent', { to, messageId: info.messageId });
      return info;
    } catch (error) {
      logger.error('Welcome email failed', { error: error.message, to });
      throw error;
    }
  }

  async sendSecurityAlert(to, alertData) {
    const { type, details, ipAddress } = alertData;

    const subject = `Security Alert: ${type}`;
    const html = `
      <h2 style="color: #d32f2f;">Security Alert</h2>
      <p>We detected the following activity on your account:</p>
      <p><strong>Type:</strong> ${type}</p>
      <p><strong>Details:</strong> ${details}</p>
      <p><strong>IP Address:</strong> ${ipAddress}</p>
      <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
      <hr>
      <p style="color: #d32f2f;">
        If this was not you, please secure your account immediately by changing your password.
      </p>
      <p><a href="https://payflow.com/account/security" style="color: #1976d2;">Secure My Account</a></p>
    `;

    try {
      const info = await this.transporter.sendMail({
        from: '"PayFlow Security" <security@payflow.com>',
        to,
        subject,
        html,
        priority: 'high'
      });

      logger.warn('Security alert sent', { to, type, messageId: info.messageId });
      return info;
    } catch (error) {
      logger.error('Security alert email failed', { error: error.message, to });
      throw error;
    }
  }

  async sendPasswordResetEmail(to, resetToken) {
    const resetLink = `https://payflow.com/reset-password?token=${resetToken}`;
    const subject = 'Password Reset Request';
    const html = `
      <h2>Password Reset Request</h2>
      <p>We received a request to reset your password.</p>
      <p>Click the link below to reset your password:</p>
      <p><a href="${resetLink}" style="color: #1976d2;">Reset Password</a></p>
      <p>This link will expire in 1 hour.</p>
      <p>If you did not request this reset, please ignore this email and your password will remain unchanged.</p>
    `;

    try {
      const info = await this.transporter.sendMail({
        from: '"PayFlow" <noreply@payflow.com>',
        to,
        subject,
        html
      });

      logger.info('Password reset email sent', { to, messageId: info.messageId });
      return info;
    } catch (error) {
      logger.error('Password reset email failed', { error: error.message, to });
      throw error;
    }
  }
}

module.exports = EmailService;
