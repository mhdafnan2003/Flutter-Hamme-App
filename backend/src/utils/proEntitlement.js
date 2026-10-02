// Shared by card-limit enforcement and priority placement. Expired store flags
// must not keep a profile at the front of another person's queue.
function hasProAccess(user, now = Date.now()) {
  if (user?.adminPro || (user?.proPlatform === 'admin' && user?.isPro)) return true;
  return Boolean(user?.storeProActive && user?.proExpiryAt &&
    new Date(user.proExpiryAt).getTime() > now);
}

function comparePriorityVotes(a, b, proVoterIds) {
  const priorityDifference = Number(proVoterIds.has(b.fromUser?.toString())) -
    Number(proVoterIds.has(a.fromUser?.toString()));
  return priorityDifference || new Date(b.createdAt) - new Date(a.createdAt);
}

module.exports = { hasProAccess, comparePriorityVotes };
