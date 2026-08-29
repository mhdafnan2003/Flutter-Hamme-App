const userService = require('../services/userService');
const interactionService = require('../services/interactionService');

function toPublicProfile(user) {
  return {
    id: user.id,
    name: user.name,
    username: user.username || null,
    instagramId: user.instagramId || '',
    profileImageUrl: user.profileImageUrl || null,
    shareCode: user.shareCode,
  };
}

async function getPublicProfile(req, res) {
  const { user, matchedBy } = await userService.getPublicProfile(req.params.identifier);
  const expiresAt = new Date(Date.now() + 60 * 1000);
  return res.status(200).json({
    user: toPublicProfile(user),
    matchedBy,
    shareCode: user.shareCode,
    expiresAt,
    isExpired: false,
  });
}

async function createAnonymousResponse(req, res) {
  const result = await interactionService.createAnonymousResponse({
    identifier: req.body.identifier,
    shareCode: req.body.shareCode,
    type: req.body.type,
    source: req.body.source || 'web',
    timestamp: req.body.timestamp,
    sessionId: req.body.sessionId,
    fromUserId: req.auth?.userId || null,
  });
  return res.status(201).json(result);
}

module.exports = {
  getPublicProfile,
  createAnonymousResponse,
};

