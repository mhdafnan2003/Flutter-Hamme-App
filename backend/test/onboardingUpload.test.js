const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const uploadController = require('../src/controllers/uploadController');

// Exercise routing, multipart validation, and rate limiting without Cloudinary.
uploadController.uploadProfileImage = (req, res) => {
  assert.equal(req.file.mimetype, 'image/jpeg');
  res.status(201).json({ imageUrl: 'https://example.test/photo.jpg' });
};
const uploadRoutes = require('../src/routes/uploadRoutes');
const errorHandler = require('../src/middleware/errorHandler');

async function withServer(run) {
  const app = express();
  app.use('/upload', uploadRoutes);
  app.use(errorHandler);
  const server = await new Promise(resolve => {
    const listening = app.listen(0, '127.0.0.1', () => resolve(listening));
  });
  try {
    await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

function photo(type = 'image/jpeg', name = 'profile.jpg', size = 1) {
  const body = new FormData();
  body.append('image', new Blob([new Uint8Array(size)], { type }), name);
  return body;
}

test('pre-registration uploads validate files and are separately rate limited', async () => {
  await withServer(async url => {
    let response = await fetch(`${url}/upload/profile-image`, { method: 'POST', body: photo() });
    assert.equal(response.status, 401, 'existing profile route still requires authentication');

    response = await fetch(`${url}/upload/onboarding-profile-image`, { method: 'POST', body: photo('text/plain', 'bad.txt') });
    assert.equal(response.status, 400);

    response = await fetch(`${url}/upload/onboarding-profile-image`, { method: 'POST', body: photo('image/jpeg', 'large.jpg', 10 * 1024 * 1024 + 1) });
    assert.equal(response.status, 413);

    for (let i = 0; i < 8; i++) {
      response = await fetch(`${url}/upload/onboarding-profile-image`, { method: 'POST', body: photo() });
      assert.equal(response.status, 201);
      assert.equal((await response.json()).imageUrl, 'https://example.test/photo.jpg');
    }
    response = await fetch(`${url}/upload/onboarding-profile-image`, { method: 'POST', body: photo() });
    assert.equal(response.status, 429);
  });
});
