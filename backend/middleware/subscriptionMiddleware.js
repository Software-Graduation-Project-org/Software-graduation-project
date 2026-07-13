const LabOwner = require('../models/Owner');

/**
 * Middleware to check if lab owner's subscription is active
 * Allows read-only access even if expired, but blocks modifications
 */
exports.requireActiveSubscription = async (req, res, next) => {
  try {
    // Only apply to lab owners
    if (req.user.role !== 'owner') {
      return next();
    }

    const owner = await LabOwner.findById(req.user._id);
    
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Check if subscription has expired
    if (owner.subscription_end && new Date() > new Date(owner.subscription_end)) {
      return res.status(403).json({ 
        message: '⚠️ This feature requires an active subscription. Your subscription has expired. Please renew to continue.',
        subscriptionExpired: true,
        subscriptionEnd: owner.subscription_end
      });
    }

    next();
  } catch (err) {
    next(err);
  }
};

/**
 * Middleware to warn about upcoming subscription expiration
 * Does not block access, just adds warning to response
 */
exports.subscriptionWarning = async (req, res, next) => {
  try {
    // Only apply to lab owners
    if (req.user.role !== 'owner') {
      return next();
    }

    const owner = await LabOwner.findById(req.user._id);
    
    if (!owner || !owner.subscription_end) {
      return next();
    }

    const today = new Date();
    const endDate = new Date(owner.subscription_end);
    const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));

    if (daysRemaining <= 30 && daysRemaining > 0) {
      req.subscriptionWarning = {
        daysRemaining,
        subscriptionEnd: owner.subscription_end,
        message: `⚠️ Your subscription expires in ${daysRemaining} day(s). Please renew soon.`
      };
    } else if (daysRemaining <= 0) {
      req.subscriptionWarning = {
        daysRemaining: 0,
        subscriptionEnd: owner.subscription_end,
        expired: true,
        message: `⚠️ Your subscription expired ${Math.abs(daysRemaining)} days ago. Please renew immediately.`
      };
    }

    next();
  } catch (err) {
    next(err);
  }
};
