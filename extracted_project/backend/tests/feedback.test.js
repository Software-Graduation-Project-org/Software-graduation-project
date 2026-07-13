const mongoose = require('mongoose');
const Feedback = require('../models/Feedback');

// Test feedback model validation (no database operations)
describe('Feedback Model Validation Tests', () => {
  test('should create feedback instance with valid data', () => {
    const feedbackData = {
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'Patient',
      target_type: 'lab',
      target_id: new mongoose.Types.ObjectId(),
      rating: 5,
      message: 'Excellent service!',
      is_anonymous: false
    };

    const feedback = new Feedback(feedbackData);

    expect(feedback.user_id).toEqual(feedbackData.user_id);
    expect(feedback.rating).toBe(5);
    expect(feedback.message).toBe('Excellent service!');
    expect(feedback.is_anonymous).toBe(false);
  });

  test('should validate required fields', () => {
    const feedback = new Feedback({
      // Missing required fields
      rating: 5
    });

    const validationError = feedback.validateSync();

    expect(validationError).toBeDefined();
    expect(validationError.errors.user_id).toBeDefined();
    expect(validationError.errors.user_model).toBeDefined();
  });

  test('should validate rating range', () => {
    const feedbackData = {
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'Patient',
      target_type: 'lab',
      target_id: new mongoose.Types.ObjectId(),
      rating: 6, // Invalid rating
      message: 'Test message'
    };

    const feedback = new Feedback(feedbackData);
    const validationError = feedback.validateSync();

    expect(validationError).toBeDefined();
    expect(validationError.errors.rating).toBeDefined();
  });

  test('should validate message length', () => {
    const longMessage = 'a'.repeat(1001); // Too long message

    const feedbackData = {
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'Patient',
      target_type: 'lab',
      target_id: new mongoose.Types.ObjectId(),
      rating: 5,
      message: longMessage
    };

    const feedback = new Feedback(feedbackData);
    const validationError = feedback.validateSync();

    expect(validationError).toBeDefined();
    expect(validationError.errors.message).toBeDefined();
  });

  test('should accept valid user models', () => {
    const validUserModels = ['Doctor', 'Patient', 'Staff', 'Owner'];

    validUserModels.forEach(userModel => {
      const feedbackData = {
        user_id: new mongoose.Types.ObjectId(),
        user_model: userModel,
        target_type: 'lab',
        target_id: new mongoose.Types.ObjectId(),
        rating: 5,
        message: 'Test message'
      };

      const feedback = new Feedback(feedbackData);
      const validationError = feedback.validateSync();

      expect(validationError).toBeUndefined();
    });
  });

  test('should validate user model enum', () => {
    const feedbackData = {
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'InvalidUser', // Invalid user model
      target_type: 'lab',
      target_id: new mongoose.Types.ObjectId(),
      rating: 5,
      message: 'Test message'
    };

    const feedback = new Feedback(feedbackData);
    const validationError = feedback.validateSync();

    expect(validationError).toBeDefined();
    expect(validationError.errors.user_model).toBeDefined();
  });

  test('should support system feedback target', () => {
    const feedbackData = {
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'Patient',
      target_type: 'system', // System feedback
      rating: 5,
      message: 'Great app experience!'
    };

    const feedback = new Feedback(feedbackData);
    const validationError = feedback.validateSync();

    expect(validationError).toBeUndefined();
    expect(feedback.target_type).toBe('system');
  });

  test('should allow null target_id for system feedback', () => {
    const feedbackData = {
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'Patient',
      target_type: 'system',
      target_id: null, // Null target_id for system feedback
      rating: 4,
      message: 'Good system performance!'
    };

    const feedback = new Feedback(feedbackData);
    const validationError = feedback.validateSync();

    expect(validationError).toBeUndefined();
    expect(feedback.target_id).toBeNull();
  });

  test('should validate target_type enum', () => {
    const feedbackData = {
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'Patient',
      target_type: 'invalid_type', // Invalid target type
      target_id: new mongoose.Types.ObjectId(),
      rating: 5,
      message: 'Test message'
    };

    const feedback = new Feedback(feedbackData);
    const validationError = feedback.validateSync();

    expect(validationError).toBeDefined();
    expect(validationError.errors.target_type).toBeDefined();
  });
});