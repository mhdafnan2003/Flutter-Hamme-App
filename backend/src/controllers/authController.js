const authService = require('../services/authService');

async function signup(req, res) {
  const result = await authService.signup(req.body);
  return res.status(201).json(result);
}

async function guestRegister(req, res) {
  const result = await authService.guestRegister(req.body);
  return res.status(201).json(result);
}

async function login(req, res) {
  const result = await authService.login(req.body);
  return res.status(200).json(result);
}

async function refresh(req, res) {
  const result = await authService.refresh(req.body.refreshToken);
  return res.status(200).json(result);
}

async function logout(req, res) {
  await authService.logout(req.auth.userId, req.body.refreshToken);
  return res.status(200).json({ message: 'Logged out successfully.' });
}

async function me(req, res) {
  const user = await authService.getCurrentUser(req.auth.userId);
  return res.status(200).json({ user: user.toJSON() });
}

module.exports = {
  signup,
  guestRegister,
  login,
  refresh,
  logout,
  me,
};
