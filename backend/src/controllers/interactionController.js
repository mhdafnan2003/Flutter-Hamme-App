const interactionService = require('../services/interactionService');
const appConfigService = require('../services/appConfigService');

async function createInteraction(req, res) {
  const result = await interactionService.createInteraction({
    fromUserId: req.auth.userId,
    shareCode: req.body.shareCode,
    type: req.body.type,
  });

  return res.status(201).json(result);
}

async function getMatches(req, res) {
  const matches = await interactionService.getMatchesForUser(req.auth.userId);
  return res.status(200).json({ matches });
}

async function respondInteraction(req, res) {
  const { senderUserId, targetUserId, type, source } = req.body;
  const authUserId = req.auth?.userId;

  if (senderUserId && authUserId && senderUserId !== authUserId) {
    return res.status(403).json({ message: 'Sender does not match auth user.' });
  }

  if (senderUserId && !authUserId) {
    return res.status(401).json({ message: 'Authentication is required for senderUserId.' });
  }

  if (authUserId) {
    const result = await interactionService.createInteractionByTargetId({
      fromUserId: authUserId,
      targetUserId,
      type,
    });
    return res.status(201).json(result);
  }

  const result = await interactionService.createAnonymousInteraction({
    targetUserId,
    type,
    source: source || 'web',
  });
  return res.status(201).json(result);
}

async function getReceivedInteractions(req, res) {
  const interactions = await interactionService.getReceivedInteractions(req.auth.userId);
  return res.status(200).json({ interactions });
}

async function createPendingInteraction(req, res) {
  const { targetUserId, type, source } = req.body;
  const result = await interactionService.createPendingInteraction({
    targetUserId,
    type,
    source,
  });
  return res.status(201).json(result);
}

async function finalizePendingInteraction(req, res) {
  const { token } = req.body;
  const currentUserId = req.auth.userId;

  const result = await interactionService.finalizePendingInteraction({
    token,
    currentUserId,
  });

  return res.status(200).json(result);
}

async function touchPendingInteraction(req, res) {
  const result = await interactionService.touchPendingInteraction(req.params.token);
  return res.status(200).json(result);
}

async function getPendingInteraction(req, res) {
  const result = await interactionService.getPendingInteraction(req.params.token);
  return res.status(200).json(result);
}

async function getLimitStatus(req, res) {
  const cardLimitStatus = await appConfigService.getCardLimitStatus(req.auth.userId);
  return res.status(200).json({ cardLimitStatus });
}

module.exports = {
  createInteraction,
  getMatches,
  respondInteraction,
  getReceivedInteractions,
  createPendingInteraction,
  touchPendingInteraction,
  finalizePendingInteraction,
  getPendingInteraction,
  getLimitStatus,
};