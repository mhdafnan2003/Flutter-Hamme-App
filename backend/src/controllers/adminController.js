const userService = require('../services/userService');
const appConfigService = require('../services/appConfigService');

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

module.exports = {
  listUsers,
  setPlan,
  getConfig,
  updateConfig,
};
