const express = require('express');
const router = express.Router();
const publicController = require('../controllers/publicController');
const { loginLimiter } = require('../middleware/rateLimitMiddleware');

/**
 * @route   POST /api/public/submit-registration
 * @desc    Patient submits registration form with personal info and test orders (no account needed)
 * @access  Public
 */
router.post('/submit-registration', loginLimiter, publicController.submitRegistration);

/**
 * @route   GET /api/public/labs
 * @desc    Get list of available labs
 * @access  Public
 */
router.get('/labs', publicController.getAllLabs);

/**
 * @route   GET /api/public/labs/:labId/tests
 * @desc    Get available tests for a specific lab
 * @access  Public
 */
router.get('/labs/:labId/tests', publicController.getLabTests);




/**
 * @route   GET /api/public/register/verify/:token
 * @desc    Verify registration token and get order details
 * @access  Public
 */
router.get('/register/verify/:token', publicController.verifyRegistrationToken);

/**
 * @route   POST /api/public/register/complete
 * @desc    Complete patient registration using token
 * @access  Public
 */
router.post('/register/complete', publicController.completeRegistration);

/**
 * @route   GET /api/public/feedback/system
 * @desc    Get system feedback for marketing pages
 * @access  Public
 */
router.get('/feedback/system', publicController.getSystemFeedback);

/**
 * @route   POST /api/public/contact
 * @desc    Submit contact form for laboratory owners interested in the system
 * @access  Public
 */
router.post('/contact', publicController.submitContactForm);

/**
 * @route   GET /api/public/subscription-tiers
 * @desc    Get available subscription tiers for lab owner registration
 * @access  Public
 */
router.get('/subscription-tiers', publicController.getSubscriptionTiers);

/**
 * @route   POST /api/public/owner/register
 * @desc    Lab owner self-registration (pending admin approval)
 * @access  Public
 */
router.post('/owner/register', publicController.registerOwner);

/**
 * @route   POST /api/public/login
 * @desc    Unified login endpoint - checks all user types in one request
 * @access  Public
 */
router.post('/login', loginLimiter, publicController.unifiedLogin);

module.exports = router;
