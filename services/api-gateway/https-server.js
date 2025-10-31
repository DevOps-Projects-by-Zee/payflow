const https = require('https');
const fs = require('fs');
const express = require('express');

function createHTTPSServer(app) {
  const options = {
    key: fs.readFileSync(process.env.SSL_KEY_PATH || './certs/server.key'),
    cert: fs.readFileSync(process.env.SSL_CERT_PATH || './certs/server.cert'),
    // Optional: Add CA certificate for mutual TLS
    // ca: fs.readFileSync('./certs/ca.cert'),
    // requestCert: true,
    // rejectUnauthorized: true
  };

  return https.createServer(options, app);
}

// For development (self-signed certificate generation)
// Run: openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.cert -days 365 -nodes

module.exports = { createHTTPSServer };
