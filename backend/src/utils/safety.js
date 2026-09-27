const ApiError = require('./ApiError');

// Shared user-generated-content safety constants (App Store Guideline 1.2).
// The app keeps its own copy of the terms version (kCurrentTermsVersion).
const CURRENT_TERMS_VERSION = 1;

const REPORT_REASONS = [
  'harassment',
  'sexual',
  'hate',
  'violence',
  'self_harm',
  'impersonation',
  'underage',
  'spam',
  'other',
];

const REPORT_REASON_LABELS = {
  harassment: 'Bullying or harassment',
  sexual: 'Nudity or sexual content',
  hate: 'Hate speech or symbols',
  violence: 'Violence or threats',
  self_harm: 'Self-harm or suicide',
  impersonation: 'Fake account or impersonation',
  underage: 'User may be under 13',
  spam: 'Spam or scam',
  other: 'Something else',
};

const REPORT_DETAILS_MAX_LENGTH = 500;

/** Missing or unknown reasons are stored as `other` so a report is never lost. */
function normalizeReportReason(reason) {
  const value = typeof reason === 'string' ? reason.trim().toLowerCase() : '';
  return REPORT_REASONS.includes(value) ? value : 'other';
}

function normalizeReportDetails(details) {
  if (typeof details !== 'string') return '';
  return details.trim().slice(0, REPORT_DETAILS_MAX_LENGTH);
}

function accountBannedError() {
  return new ApiError(
    403,
    'Your account has been suspended for violating the Hamme Terms of Use.',
    { code: 'ACCOUNT_BANNED' }
  );
}

function voteBlockedError() {
  return new ApiError(403, "You can't vote for this profile.", {
    code: 'VOTE_BLOCKED',
  });
}

function objectionableContentError(field, label) {
  return new ApiError(
    400,
    `That ${label} isn't allowed on Hamme. Please choose another.`,
    { code: 'OBJECTIONABLE_CONTENT', field }
  );
}

module.exports = {
  CURRENT_TERMS_VERSION,
  REPORT_REASONS,
  REPORT_REASON_LABELS,
  REPORT_DETAILS_MAX_LENGTH,
  normalizeReportReason,
  normalizeReportDetails,
  accountBannedError,
  voteBlockedError,
  objectionableContentError,
};
