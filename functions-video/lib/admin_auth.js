function _isUserAdmin(userDoc) {
  if (!userDoc.exists) return false;
  const data = userDoc.data() || {};
  if (data.role === 'admin') return true;
  if (Array.isArray(data.roles) && data.roles.includes('admin')) return true;
  return false;
}

module.exports = {
  _isUserAdmin,
};
