const roleMiddleware = (allowedRoles = []) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ message: 'User not authenticated' });
    }

    // Case-insensitive role comparison to handle "doctor" vs "Doctor"
    const userRole = req.user.role?.toLowerCase();
    const allowedRolesLower = allowedRoles.map(role => role.toLowerCase());

    if (!allowedRolesLower.includes(userRole)) {
      return res.status(403).json({ message: 'Access forbidden: insufficient permissions' });
    }

    next();
  };
};

module.exports = roleMiddleware;
