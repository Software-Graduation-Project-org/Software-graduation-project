const app = require('./app');
const logger = require('./utils/logger');

const PORT = process.env.PORT || 5001;
const HOST = process.env.HOST || '0.0.0.0';

console.log(`Attempting to start server on ${HOST}:${PORT}`);

try {
  const server = app.listen(PORT, HOST, () => {
    console.log(`✅ Server successfully listening on ${HOST}:${PORT}`);
    logger.info(`Server running on ${HOST}:${PORT}`);
  });

  server.on('error', (err) => {
    console.error('❌ Server failed to start:', err);
    logger.error('Server failed to start', { error: err.message });
    process.exit(1);
  });

  server.on('listening', () => {
    console.log(`✅ Server is now listening on ${HOST}:${PORT}`);
  });

  // Handle uncaught exceptions
  process.on('uncaughtException', (err) => {
    console.error('❌ Uncaught Exception:', err);
    logger.error('Uncaught Exception', { error: err.message, stack: err.stack });
    process.exit(1);
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
    logger.error('Unhandled Rejection', { reason: reason });
    process.exit(1);
  });

  // Keep the process alive
  process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully...');
    server.close(() => {
      console.log('Server closed.');
      process.exit(0);
    });
  });

} catch (error) {
  console.error('❌ Failed to create server:', error);
  logger.error('Failed to create server', { error: error.message });
  process.exit(1);
}
