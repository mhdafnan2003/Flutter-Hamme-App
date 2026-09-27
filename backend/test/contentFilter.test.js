const test = require('node:test');
const assert = require('node:assert/strict');

const { isObjectionable } = require('../src/utils/contentFilter');

// Real names and handles that contain a blocked word. Add to this list whenever
// a real user reports being rejected.
const REAL_NAMES = [
  'Harshit', 'Akshit', 'Shital', 'sh1tal', 'Shithil', 'Anusha', 'Dhanush', 'Wankhede',
  'Pornchai', 'Porntip', 'Pornthip', 'Pornpimol', 'Pornima', 'Boobathi', 'Boobalan',
  'Fagun', 'Fagoon', 'Sexena', 'Sussex', 'Dickson', 'Pat Cummins', 'rahul_455',
  'Sh1tal Patil',
];

const OBJECTIONABLE = [
  'fuck', 'f.u.c.k', 'sh1t', 'shithead', 'bitch', 'porn', 'pornhub', 'porn chai',
  'fag', 'faggot', 'boobs', 'sexy', 'madarchod', 'bhosdike', 'चूतिया',
];

test('real names are allowed', () => {
  for (const name of REAL_NAMES) {
    assert.equal(isObjectionable(name), false, `"${name}" should be allowed`);
  }
});

test('profanity is rejected', () => {
  for (const word of OBJECTIONABLE) {
    assert.equal(isObjectionable(word), true, `"${word}" should be rejected`);
  }
});
