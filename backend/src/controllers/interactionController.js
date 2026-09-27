const interactionService = require('../services/interactionService');
const appConfigService = require('../services/appConfigService');
const blockService = require('../services/blockService');
const reportService = require('../services/reportService');

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
  const { senderUserId, targetUserId, interactionId, type, source } = req.body;
  const authUserId = req.auth?.userId;

  if (senderUserId && authUserId && senderUserId !== authUserId) {
    return res.status(403).json({ message: 'Sender does not match auth user.' });
  }

  if (senderUserId && !authUserId) {
    return res.status(401).json({ message: 'Authentication is required for senderUserId.' });
  }

  if (authUserId) {
    if (interactionId) {
      const result = await interactionService.respondToAnonymousInteraction({
        currentUserId: authUserId,
        interactionId,
        type,
      });
      return res.status(201).json(result);
    }
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
  const interactions = await interactionService.getReceivedInteractions(req.auth.userId, {
    // 'all' = full list (Inbox); default = the Play queue.
    scope: req.query.scope,
  });
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

async function reportInteraction(req, res) {
  // Older app builds send no body: report as `other` and block (their old behaviour).
  const { reason, details, block } = req.body || {};
  const result = await reportService.reportInteraction({
    reporterId: req.auth.userId,
    interactionId: req.params.id,
    reason,
    details,
    block: block !== false,
  });
  return res.status(201).json({ reportId: result.reportId, hidden: true, blocked: result.blocked });
}

async function hideInteraction(req, res) {
  await blockService.hideInteraction(req.auth.userId, req.params.id);
  return res.status(200).json({ hidden: true });
}

async function blockInteractionSender(req, res) {
  const blocked = await blockService.blockInteractionSender(req.auth.userId, req.params.id);
  return res.status(200).json({ blocked, hidden: true });
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
  reportInteraction,
  hideInteraction,
  blockInteractionSender,
};
