function buildDefaultAvatarUrl(name) {
  const safeName = (name || 'User').trim() || 'User';
  const encodedName = encodeURIComponent(safeName);
  return `https://ui-avatars.com/api/?name=${encodedName}&background=8f48fa&color=ffffff&size=256&rounded=true`;
}

module.exports = buildDefaultAvatarUrl;
