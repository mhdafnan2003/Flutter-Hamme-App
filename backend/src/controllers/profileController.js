const blockService = require('../services/blockService');
const reportService = require('../services/reportService');
const userService = require('../services/userService');
const { CURRENT_TERMS_VERSION } = require('../utils/safety');

function toPublicProfile(user) {
  return {
    id: user.id,
    name: user.name,
    instagramId: user.instagramId,
    avatarUrl: user.profileImageUrl,
    username: user.username,
    shareCode: user.shareCode,
  };
}

async function getMe(req, res) {
  const user = await userService.getMe(req.auth.userId);
  return res.status(200).json({ user: user.toJSON() });
}

async function updateMe(req, res) {
  const user = await userService.updateMe(req.auth.userId, req.body);
  return res.status(200).json({ user: user.toJSON() });
}

async function deleteMe(req, res) {
  await userService.deleteMe(req.auth.userId);
  return res.status(200).json({ message: 'Account deleted permanently.' });
}

async function getPublicProfile(req, res) {
  const { user, matchedBy } = await userService.getPublicProfile(req.params.shareCode);
  return res.status(200).json({ user: toPublicProfile(user), matchedBy });
}

async function registerDeviceToken(req, res) {
  const { token, platform } = req.body;
  await userService.registerDeviceToken(req.auth.userId, { token, platform });
  return res.status(200).json({ message: 'Device token registered.' });
}

async function unregisterDeviceToken(req, res) {
  const { token } = req.body;
  await userService.unregisterDeviceToken(req.auth.userId, token);
  return res.status(200).json({ message: 'Device token removed.' });
}

async function acceptTerms(req, res) {
  const version = req.body?.version ?? CURRENT_TERMS_VERSION;
  const user = await userService.acceptTerms(req.auth.userId, version);
  return res.status(200).json({ user: user.toJSON() });
}

async function reportProfile(req, res) {
  const { reason, details, block } = req.body || {};
  const result = await reportService.reportProfile({
    reporterId: req.auth.userId,
    reportedUserId: req.params.userId,
    reason,
    details,
    block: block !== false,
  });
  return res.status(201).json(result);
}

async function blockUser(req, res) {
  await blockService.blockUser(req.auth.userId, req.params.userId);
  return res.status(200).json({ blocked: true });
}

async function listBlocked(req, res) {
  const result = await blockService.listBlocked(req.auth.userId);
  return res.status(200).json(result);
}

async function unblockUser(req, res) {
  await blockService.unblockUser(req.auth.userId, req.params.userId);
  return res.status(200).json({ unblocked: true });
}

async function clearAnonymousBlocks(req, res) {
  const cleared = await blockService.clearAnonymousBlocks(req.auth.userId);
  return res.status(200).json({ cleared });
}

module.exports = {
  getMe,
  updateMe,
  deleteMe,
  getPublicProfile,
  registerDeviceToken,
  unregisterDeviceToken,
  acceptTerms,
  reportProfile,
  blockUser,
  listBlocked,
  unblockUser,
  clearAnonymousBlocks,
};
