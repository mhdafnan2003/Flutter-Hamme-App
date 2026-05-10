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
  return res.status(200).json({ user: toPublicProfile(user), matchedBy });
}

async function createAnonymousResponse(req, res) {
  const result = await interactionService.createAnonymousResponse({
    identifier: req.body.identifier,
    type: req.body.type,
    source: req.body.source || 'web',
  });
  return res.status(201).json(result);
}

module.exports = {
  getPublicProfile,
  createAnonymousResponse,
};

