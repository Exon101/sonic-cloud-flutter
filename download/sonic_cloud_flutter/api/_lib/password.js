// Password hashing using Node's built-in scrypt (no npm dependencies).
//
// scrypt is the recommended password hashing function per OWASP — it's
// memory-hard (resistant to GPU/ASIC attacks) and tunable via N (CPU/memory
// cost), r (block size), p (parallelism). We use the defaults recommended
// by the Node.js docs (N=16384, r=8, p=1) which take ~100ms per hash —
// fast enough for sign-in, slow enough to make brute-force impractical.
//
// Storage format: `scrypt:<N>:<r>:<p>:<saltHex>:<hashHex>`
// The salt is 16 bytes (128 bits), the hash is 64 bytes (512 bits).

const crypto = require('crypto');

const DEFAULT_N = 16384; // CPU/memory cost (must be a power of 2)
const DEFAULT_R = 8;    // block size
const DEFAULT_P = 1;    // parallelism
const KEY_LENGTH = 64;  // output length in bytes
const SALT_LENGTH = 16; // salt length in bytes

/// Hash a password with a random salt. Returns `scrypt:N:r:p:<saltHex>:<hashHex>`.
function hashPassword(password) {
  return new Promise((resolve, reject) => {
    const salt = crypto.randomBytes(SALT_LENGTH);
    crypto.scrypt(password, salt, KEY_LENGTH, { N: DEFAULT_N, r: DEFAULT_R, p: DEFAULT_P }, (err, derived) => {
      if (err) return reject(err);
      resolve(`scrypt:${DEFAULT_N}:${DEFAULT_R}:${DEFAULT_P}:${salt.toString('hex')}:${derived.toString('hex')}`);
    });
  });
}

/// Verify a password against a stored hash. Returns true on match, false
/// otherwise. Uses constant-time comparison to prevent timing attacks.
function verifyPassword(password, storedHash) {
  return new Promise((resolve, reject) => {
    if (!storedHash || typeof storedHash !== 'string') {
      return resolve(false);
    }
    const parts = storedHash.split(':');
    if (parts.length !== 6 || parts[0] !== 'scrypt') {
      return resolve(false);
    }
    const N = parseInt(parts[1], 10);
    const r = parseInt(parts[2], 10);
    const p = parseInt(parts[3], 10);
    const salt = Buffer.from(parts[4], 'hex');
    const expectedHash = Buffer.from(parts[5], 'hex');
    crypto.scrypt(password, salt, expectedHash.length, { N, r, p }, (err, derived) => {
      if (err) return reject(err);
      // constant-time comparison
      if (derived.length !== expectedHash.length) return resolve(false);
      resolve(crypto.timingSafeEqual(derived, expectedHash));
    });
  });
}

/// Validate password strength. Returns null if OK, or an error message.
function validatePassword(password) {
  if (!password || typeof password !== 'string') {
    return 'Password is required';
  }
  if (password.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (password.length > 1000) {
    return 'Password is too long (max 1000 characters)';
  }
  return null;
}

/// Validate email format. Returns null if OK, or an error message.
function validateEmail(email) {
  if (!email || typeof email !== 'string') {
    return 'Email is required';
  }
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!re.test(email)) {
    return 'Invalid email format';
  }
  return null;
}

module.exports = {
  hashPassword,
  verifyPassword,
  validatePassword,
  validateEmail,
};
