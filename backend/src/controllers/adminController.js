const userService = require('../services/userService');

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

module.exports = {
  listUsers,
  setPlan,
};
