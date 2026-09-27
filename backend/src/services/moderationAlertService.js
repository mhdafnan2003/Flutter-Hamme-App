const env = require('../config/env');
const logger = require('../utils/logger');
const { REPORT_REASON_LABELS } = require('../utils/safety');

// Long enough for Slack/Discord, short enough not to hold up the report request
// (the caller awaits it because serverless hosts may freeze after responding).
const WEBHOOK_TIMEOUT_MS = 2500;

// User-supplied text must not inject Slack control sequences such as <!channel>.
function clean(value, maxLength = 200) {
  return String(value || '')
    .replace(/[<>]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength);
}

function describePerson(snapshot) {
  if (!snapshot) return 'unknown user';
  const name = clean(snapshot.name, 80) || 'unnamed user';
  return snapshot.username ? `${name} (@${clean(snapshot.username, 40)})` : name;
}

function describeTarget(report) {
  if (report.targetType === 'profile') {
    return `profile of ${describePerson(report.reportedUserSnapshot)}`;
  }
  const vote = report.interactionType ? `${report.interactionType} vote` : 'vote';
  if (report.anonymous) {
    const session = report.anonymousSessionId
      ? ` (web session ${clean(report.anonymousSessionId, 12)}...)`
      : '';
    return `anonymous ${vote}${session}`;
  }
  return `${vote} from ${describePerson(report.reportedUserSnapshot)}`;
}

function buildMessage(report) {
  const adminUrl = env.publicBaseUrl
    ? `${env.publicBaseUrl.replace(/\/+$/, '')}/api/v1/admin`
    : 'the admin panel';
  return [
    `New Hamme report: ${REPORT_REASON_LABELS[report.reason] || report.reason}`,
    `Target: ${describeTarget(report)}`,
    `Reported by: ${describePerson(report.reporterSnapshot)}`,
    report.details ? `Details: "${clean(report.details, 500)}"` : null,
    `Report ID: ${report._id}`,
    `Review and act within 24 hours in ${adminUrl}.`,
  ]
    .filter(Boolean)
    .join('\n');
}

/**
 * Posts a new report to the moderators' Slack or Discord incoming webhook
 * (MODERATION_WEBHOOK_URL). Never throws: a failed alert must not fail the
 * user's report, which is already saved and visible in the admin panel.
 */
async function notifyNewReport(report) {
  if (!env.moderationWebhookUrl) return;
  const text = buildMessage(report);
  try {
    const response = await fetch(env.moderationWebhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      // Slack reads `text`, Discord reads `content`; each ignores the other.
      // allowed_mentions stops Discord from pinging on "@" in user text.
      body: JSON.stringify({ text, content: text.slice(0, 2000), allowed_mentions: { parse: [] } }),
      signal: AbortSignal.timeout(WEBHOOK_TIMEOUT_MS),
    });
    if (!response.ok) {
      logger.warn(`Moderation webhook responded ${response.status} for report ${report._id}.`);
    }
  } catch (error) {
    logger.warn(`Moderation webhook failed for report ${report._id}: ${error.message}`);
  }
}

module.exports = { notifyNewReport };
