const userService = require('../services/userService');
const appConfigService = require('../services/appConfigService');
const moderationService = require('../services/moderationService');
const reportService = require('../services/reportService');

async function listUsers(req, res) {
  const result = await userService.listUsers({
    search: req.query.search,
    page: req.query.page,
    limit: req.query.limit,
  });
  return res.status(200).json(result);
}

async function setPlan(req, res) {
  const user = await userService.setProStatus(req.params.id, req.body.isPro);
  return res.status(200).json({ user: user.toJSON() });
}

async function getConfig(req, res) {
  const config = await appConfigService.getConfig();
  return res.status(200).json({ config });
}

async function updateConfig(req, res) {
  const { freeUserCardLimit, cardCooldownMinutes } = req.body;
  const config = await appConfigService.updateConfig({ freeUserCardLimit, cardCooldownMinutes });
  return res.status(200).json({ config });
}

async function listReports(req, res) {
  const result = await reportService.listReports({
    status: req.query.status,
    page: req.query.page,
    limit: req.query.limit,
  });
  return res.status(200).json(result);
}

async function actOnReport(req, res) {
  const report = await moderationService.actOnReport(req.params.id, {
    action: req.body.action,
    note: req.body.note,
  });
  return res.status(200).json({ report });
}

async function banUser(req, res) {
  const user = await moderationService.banUser(req.params.id, {
    reason: req.body?.reason,
  });
  return res.status(200).json({ user: user.toJSON() });
}

async function unbanUser(req, res) {
  const user = await moderationService.unbanUser(req.params.id);
  return res.status(200).json({ user: user.toJSON() });
}

module.exports = {
  listUsers,
  setPlan,
  getConfig,
  updateConfig,
  listReports,
  actOnReport,
  banUser,
  unbanUser,
};
