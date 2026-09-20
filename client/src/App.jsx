import { useEffect, useState } from 'react';

const fallbackProfileImage = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80';
const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api/v1';
const flutterWebBaseUrl = import.meta.env.VITE_FLUTTER_WEB_URL ?? '';
const sessionStorageKey = 'hamme_web_session_id';
const votedCodesKey = 'hamme_voted_codes';
const voteCooldownMs = 24 * 60 * 60 * 1000;
const pendingTtlSeconds = Math.max(30, Number(import.meta.env.VITE_PENDING_TTL_SECONDS) || 60);
const pendingTtlMs = pendingTtlSeconds * 1000;
const currentPath = window.location.pathname.replace(/\/+$/, '') || '/';
const isPrivacyPolicyRoute = currentPath === '/privacy-policy';
const isTermsOfServiceRoute = currentPath === '/terms-of-service' || currentPath === '/terms';
const isSupportRoute = currentPath === '/support';

function hasAlreadyVoted(code) {
  if (!code) return false;
  try {
    const voted = JSON.parse(window.localStorage.getItem(votedCodesKey) || '{}');
    const votedAt = Number(voted[code]);
    if (Number.isFinite(votedAt) && Date.now() - votedAt < voteCooldownMs) {
      return true;
    }

    // Remove expired (and legacy non-timestamp) entries so this browser can
    // vote for the profile again after the 24-hour server cooldown.
    if (Object.hasOwn(voted, code)) {
      delete voted[code];
      window.localStorage.setItem(votedCodesKey, JSON.stringify(voted));
    }
    return false;
  } catch {
    return false;
  }
}

function markAsVoted(code) {
  if (!code) return;
  try {
    const voted = JSON.parse(window.localStorage.getItem(votedCodesKey) || '{}');
    voted[code] = Date.now();
    window.localStorage.setItem(votedCodesKey, JSON.stringify(voted));
  } catch {}
}

function readShareCodeFromPath() {
  const parts = window.location.pathname.split('/').filter(Boolean);
  // New poll links use /poll so installed apps leave them in the browser.
  // Continue accepting /u links when they reach the website for compatibility.
  if (parts.length >= 2 && (parts[0] === 'poll' || parts[0] === 'u')) {
    const rawCode = decodeURIComponent(parts[1]);
    return rawCode.replace(/[.,;:]+$/, '');
  }
  return null;
}

function generateSessionId() {
  if (window.crypto && typeof window.crypto.randomUUID === 'function') {
    return window.crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function buildDeepLink({ shareCode, type, token }) {
  const params = new URLSearchParams();
  if (shareCode) params.set('code', shareCode);
  if (type) params.set('type', type);
  if (token) params.set('token', token);
  return `hamme://open?${params.toString()}`;
}

function App() {
  if (isPrivacyPolicyRoute) {
    return <PrivacyPolicyPage />;
  }
  if (isTermsOfServiceRoute) {
    return <TermsOfServicePage />;
  }
  if (isSupportRoute) {
    return <SupportPage />;
  }

  return <ShareFlowApp />;
}

function ShareFlowApp() {
  const shareCode = readShareCodeFromPath();
  const [isSent, setIsSent] = useState(false);
  const [alreadyVoted] = useState(() => hasAlreadyVoted(shareCode));
  const [secondsLeft, setSecondsLeft] = useState(pendingTtlSeconds);
  const [expiresAt, setExpiresAt] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);
  const [profileError, setProfileError] = useState('');
  const [submittingType, setSubmittingType] = useState('');
  const [selectedType, setSelectedType] = useState('');
  const [submitError, setSubmitError] = useState('');
  const [interactionResult, setInteractionResult] = useState(null);
  const isExpired = secondsLeft === 0;

  useEffect(() => {
    if (!isSent || !expiresAt) {
      return undefined;
    }

    const timer = setInterval(() => {
      const remainingMs = new Date(expiresAt).getTime() - Date.now();
      setSecondsLeft(Math.max(Math.ceil(remainingMs / 1000), 0));
    }, 1000);

    return () => clearInterval(timer);
  }, [isSent, expiresAt]);

  // If the user already has the app installed, try opening it directly as
  // soon as the response is sent. If the app isn't installed, this is a
  // no-op and the user just stays on the reveal screen below.
  useEffect(() => {
    if (!isSent || !interactionResult) {
      return;
    }

    const deepLink = buildDeepLink({
      shareCode,
      type: selectedType,
      token: interactionResult.pendingToken,
    });

    window.location.href = deepLink;
    console.info('[Web] auto app-open attempted', { deepLink });
  }, [isSent, interactionResult, shareCode, selectedType]);

  useEffect(() => {
    const controller = new AbortController();

    async function loadProfile() {
      if (!shareCode) {
        setProfileError('Invalid share link.');
        setLoadingProfile(false);
        return;
      }

      try {
        const response = await fetch(
          `${apiBaseUrl}/public-profile/${encodeURIComponent(shareCode)}`,
          { signal: controller.signal },
        );
        if (!response.ok) {
          throw new Error(`Failed with status ${response.status}`);
        }
        const data = await response.json();
        setProfile(data.user ?? null);
        if (data.expiresAt) {
          const expires = new Date(data.expiresAt);
          setExpiresAt(expires.toISOString());
          const remainingMs = expires.getTime() - Date.now();
          setSecondsLeft(Math.max(Math.ceil(remainingMs / 1000), 0));
        } else {
          const fallbackExpires = new Date(Date.now() + pendingTtlMs);
          setExpiresAt(fallbackExpires.toISOString());
          setSecondsLeft(pendingTtlSeconds);
        }
        setProfileError('');
        console.info('[Web] link opened', { shareCode });
      } catch (error) {
        if (error.name !== 'AbortError') {
          setProfileError('Profile not found.');
        }
      } finally {
        setLoadingProfile(false);
      }
    }

    loadProfile();
    return () => controller.abort();
  }, [shareCode]);

  const handleAnswer = async (type) => {
    setSubmittingType(type);
    setSelectedType(type);
    setSubmitError('');
    try {
      if (!shareCode) {
        throw new Error('Missing share code');
      }

      const now = Date.now();
      const sessionId =
        window.localStorage.getItem(sessionStorageKey) ??
        generateSessionId();
      window.localStorage.setItem(sessionStorageKey, sessionId);

      const response = await fetch(`${apiBaseUrl}/anonymous-response`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          shareCode,
          type,
          timestamp: now,
          sessionId,
          source: 'web_local',
        }),
      });
      if (!response.ok) {
        throw new Error(`Failed with status ${response.status}`);
      }
      const data = await response.json();
      setInteractionResult(data);
      setIsSent(true);
      markAsVoted(shareCode);
      if (data.expiresAt) {
        const expires = new Date(data.expiresAt);
        setExpiresAt(expires.toISOString());
        const remainingMs = expires.getTime() - Date.now();
        setSecondsLeft(Math.max(Math.ceil(remainingMs / 1000), 0));
      } else {
        const fallbackExpires = new Date(now + pendingTtlMs);
        setExpiresAt(fallbackExpires.toISOString());
        setSecondsLeft(pendingTtlSeconds);
      }
      console.info('[Web] option selected', { shareCode, type });
    } catch {
      setSubmitError('Could not submit response. Please try again.');
    } finally {
      setSubmittingType('');
    }
  };

  if (loadingProfile) {
    return (
      <main className="min-h-screen bg-[linear-gradient(180deg,#9b63f7_0%,#8f48fa_48%,#7c35ff_100%)] text-white">
        <section className="mx-auto flex min-h-screen w-full max-w-[360px] items-center justify-center px-4 text-center">
          <p className="text-lg font-bold">Loading profile...</p>
        </section>
      </main>
    );
  }

  if (profileError || !profile) {
    return (
      <main className="min-h-screen bg-[linear-gradient(180deg,#9b63f7_0%,#8f48fa_48%,#7c35ff_100%)] text-white">
        <section className="mx-auto flex min-h-screen w-full max-w-[360px] items-center justify-center px-4 text-center">
          <p className="text-lg font-bold">{profileError || 'Profile unavailable.'}</p>
        </section>
      </main>
    );
  }

  const profileName = profile.name ?? 'User';
  const profileImage = profile.profileImageUrl || fallbackProfileImage;

  return (
    <main className="min-h-screen overflow-hidden bg-[linear-gradient(180deg,#9b63f7_0%,#8f48fa_48%,#7c35ff_100%)] text-white">
      <section className={`mx-auto flex min-h-screen w-full max-w-[360px] flex-col items-center px-4 pb-8 text-center ${isSent || alreadyVoted ? 'pt-[82px]' : 'pt-[132px]'}`}>
        {isSent ? (
          <RevealScreen
            secondsLeft={secondsLeft}
            isExpired={isExpired}
            profileName={profileName}
            profileImage={profileImage}
            isMatch={interactionResult?.isMatch ?? interactionResult?.matched}
            pendingToken={interactionResult?.pendingToken}
            shareCode={shareCode}
            selectedType={selectedType}
          />
        ) : alreadyVoted ? (
          <AlreadyVotedScreen profileName={profileName} profileImage={profileImage} />
        ) : (
          <QuestionScreen
            onAnswer={handleAnswer}
            profileImage={profileImage}
            profileName={profileName}
            submittingType={submittingType}
            submitError={submitError}
          />
        )}

        <footer className="mt-auto flex flex-col items-center">
          <FriendsPlaying />
          <h1 className="m-0 leading-none">
            <img src="/weblogohome.png" alt="Hamme" width={68} height={33} className="h-[33px] w-[68px] object-contain" />
          </h1>
          <p className="mt-2 text-[12px] font-extrabold">play games &amp; meet people</p>
          <nav className="mt-6 flex items-center gap-4 text-[12px] font-bold text-white/70">
            <a href="/terms-of-service" className="transition hover:text-white">Terms</a>
            <a href="/privacy-policy" className="transition hover:text-white">Privacy</a>
          </nav>
        </footer>
      </section>
    </main>
  );
}

const playingFriends = [
  { letter: 'S', className: 'bg-[#ff4f81] text-white' },
  { letter: 'K', className: 'bg-[#20d67b] text-white' },
  { letter: 'R', className: 'bg-[#4f95ff] text-white' },
  { letter: 'N', className: 'bg-[#ffd43b] text-[#5b21b6]' },
  { letter: 'A', className: 'bg-[#ff5757] text-white' },
];

// Cuts a transparent 1.5px ring around the next avatar (24px wide, overlapped by 4px),
// so the gap always matches the page background.
const avatarCutout = {
  WebkitMaskImage: 'radial-gradient(circle at 32px 12px, transparent 13.5px, #000 14.5px)',
  maskImage: 'radial-gradient(circle at 32px 12px, transparent 13.5px, #000 14.5px)',
};

function FriendsPlaying() {
  return (
    <div className="mb-[72px] flex flex-col items-center gap-3" role="status" aria-label="6 friends playing now">
      <div className="flex h-6 w-[118px] items-center gap-1.5" aria-hidden="true">
        <span className="relative flex h-2 w-2 shrink-0">
          <span className="absolute inline-flex h-full w-full rounded-full bg-[#22ff44] opacity-70 motion-safe:animate-ping" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-[#22ff44] shadow-[0_0_8px_3px_rgba(34,255,68,0.55)]" />
        </span>
        <div className="flex items-center">
          {playingFriends.map((friend, index) => (
            <span
              key={friend.letter}
              className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[11px] font-black ${friend.className} ${index > 0 ? '-ml-1' : ''}`}
              style={index < playingFriends.length - 1 ? avatarCutout : undefined}
            >
              {friend.letter}
            </span>
          ))}
        </div>
      </div>
      <p className="flex h-[22px] w-[202px] items-center justify-center whitespace-nowrap text-[14px] font-extrabold leading-none tracking-[-0.01em]">
        👆 6 friends playing now 👆
      </p>
    </div>
  );
}

const legal = {
  lastUpdated: 'September 15, 2026',
  supportEmail: 'support@hamme.app',
};

function MailLink({ email }) {
  return (
    <a className="legal-link" href={`mailto:${email}`}>
      {email}
    </a>
  );
}

function LegalTable({ columns, rows }) {
  return (
    <div className="legal-table">
      <table>
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column} scope="col">{column}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row[0]}>
              {row.map((cell, index) => (
                <td key={index}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PrivacyPolicyPage() {
  return (
    <main className="privacy-shell">
      <section className="privacy-card">
        <div className="privacy-eyebrow">Hamme</div>
        <h1>Privacy Policy</h1>
        <p className="privacy-meta">Last updated: {legal.lastUpdated}</p>
        <p>
          This Privacy Policy explains what information Hamme (“we”, “us”) collects when you use the Hamme mobile app,
          the Hamme response pages on the web, and related services (together, the “Service”), and what we do with it.
        </p>
        <p>
          We are the data controller (data fiduciary) for this information. Contact us at <MailLink email={legal.supportEmail} />.
        </p>
        <p>This policy covers two different groups of people:</p>
        <ul>
          <li>
            <strong>Account holders</strong> — people who install the app and create a Hamme account.
          </li>
          <li>
            <strong>Responders</strong> — people who open someone’s Hamme link and choose a reaction on the web without
            installing the app. <a className="legal-link" href="#web-responders">Section 3</a> is written for you.
          </li>
        </ul>

        <h2>1. Information We Collect From Account Holders</h2>
        <h3>Information you give us when you sign up</h3>
        <ul>
          <li>Your name (as you enter it, displayed to other users)</li>
          <li>
            Your date of birth, used to confirm you meet our minimum age and to apply age-appropriate restrictions
          </li>
          <li>Your profile photo, which you upload</li>
          <li>Optionally, your Instagram and/or Snapchat username, if you choose to add it</li>
        </ul>
        <p>
          We do not ask for your email address, phone number, or postal address at signup. If you email our support
          address, we will have your email address from that message.
        </p>

        <h3>Information generated by your use of the Service</h3>
        <ul>
          <li>Your share link or share code</li>
          <li>Reactions you receive, including the reaction chosen and whether the sender has a Hamme account</li>
          <li>Reactions you send to other users</li>
          <li>Matches, meaning cases where you and another user chose the same reaction</li>
          <li>App activity such as screens opened, features used, cards viewed, and session timestamps</li>
        </ul>

        <h3>Information collected automatically</h3>
        <ul>
          <li>Device and app data: device model, operating system version, app version, language, and time zone</li>
          <li>
            IP address and approximate location derived from it (country or region level; we do not collect GPS
            location)
          </li>
          <li>Log and diagnostic data, including crash reports and error traces</li>
          <li>Identifiers used for install attribution and to link a shared link to the resulting install</li>
        </ul>

        <h3>Purchases</h3>
        <p>
          If you buy a paid feature, Apple or Google processes the payment. We receive confirmation that a purchase or
          subscription is active. We never receive your card number or bank details.
        </p>

        <h3>Notifications</h3>
        <p>If you allow notifications, we store a push token so we can tell you when you have new reactions.</p>

        <h2>2. How We Use This Information</h2>
        <LegalTable
          columns={['Purpose', 'Information used']}
          rows={[
            ['Create and run your account', 'Name, date of birth, photo, handle'],
            ['Show your profile on your share page', 'Name, photo'],
            ['Deliver reactions and detect matches', 'Reactions, share code, account IDs'],
            [
              'Confirm you meet the minimum age and apply age restrictions',
              'Date of birth, age signals from app stores',
            ],
            ['Send you notifications you asked for', 'Push token'],
            [
              'Keep the Service safe: detect abuse, spam, fake accounts, and manipulated reactions',
              'Device data, IP address, activity, reports',
            ],
            [
              'Moderate content, including reviewing profile photos and handling reports',
              'Photo, reports, account data',
            ],
            ['Fix bugs and improve the app', 'Diagnostic and activity data'],
            ['Measure which shared links lead to installs', 'Attribution identifiers, device data'],
            ['Comply with law and enforce our Terms', 'Any of the above, as necessary'],
          ]}
        />
        <p>
          Where the law requires a legal basis, we rely on: performance of our contract with you (running your account
          and delivering reactions), our legitimate interests (safety, abuse prevention, improving the Service), your
          consent (optional handle, notifications, optional analytics where required), and legal obligation.
        </p>
        <p>
          We do not use your information for advertising, and we do not sell or share it for cross-context behavioural
          advertising.
        </p>

        <h2 id="web-responders">3. If You Responded to Someone’s Link Without Installing the App</h2>
        <p>If you opened a Hamme link and chose a reaction on the web, here is exactly what happens.</p>
        <p>
          <strong>What we collect from you:</strong>
        </p>
        <ul>
          <li>The reaction you chose and the link it was given through</li>
          <li>Your IP address, device type, browser type, and the time of your response</li>
          <li>
            A cookie or browser identifier, so the same person cannot repeatedly submit reactions to one link, and so
            your response can be connected to your account if you later install the app
          </li>
        </ul>
        <p>
          <strong>What we do with it:</strong> we deliver your reaction to the person whose link you used, and we use
          the technical data to prevent abuse and duplicate submissions.
        </p>
        <p>
          <strong>What the recipient sees:</strong> the reaction you chose, shown without your name, because we do not
          know who you are. If you later install the app and create an account, your name and photo become attached to
          the reaction you already sent, and the recipient will then see who it was from. If you do not want to be
          identified, do not install the app after responding.
        </p>
        <p>
          We do not collect your name, photo, email, or social handle on the web. We do not build an advertising
          profile of you.
        </p>
        <p>
          To have your response and associated technical data deleted, email <MailLink email={legal.supportEmail} /> with
          the approximate date and the link you responded to, or delete your account from inside the app (Settings →
          Delete Account).
        </p>

        <h2>4. What Is Visible to Others</h2>
        <ul>
          <li>
            <strong>Your name and profile photo are public.</strong> They appear on your Hamme share page, which anyone
            with your link can open without an account. Do not upload a photo you would not want seen publicly.
          </li>
          <li>Your date of birth is never shown to other users.</li>
          <li>Your social handle is shown only if you added one, and only where the app indicates.</li>
          <li>
            A reaction you send is not revealed to the recipient unless both of you chose the same reaction. We do not
            tell anyone that you chose a reaction they did not also choose.
          </li>
          <li>Reactions you receive are private to you.</li>
        </ul>

        <h2>5. Who We Share Information With</h2>
        <p>We do not sell your personal information. We share it only as follows.</p>
        <LegalTable
          columns={['Recipient', 'What they receive', 'Why']}
          rows={[
            ['Cloud hosting provider (Vercel, MongoDB Atlas, Cloudinary)', 'All stored data', 'Hosting and databases'],
            [
              'Attribution provider (Google Play Install Referrer)',
              'Device and install identifiers, IP address',
              'Linking a shared link to the resulting install',
            ],
            [
              'Analytics and crash reporting (Firebase)',
              'Device data, activity events, crash logs',
              'Diagnostics and product analytics',
            ],
            ['Push provider (Firebase Cloud Messaging)', 'Push token', 'Sending notifications'],
            ['Moderation or image-scanning provider, if used', 'Profile photos', 'Detecting objectionable content'],
            ['Apple, Google', 'Purchase and subscription status', 'Processing payments'],
            ['Law enforcement or regulators', 'Only what is legally required', 'Legal obligation, safety'],
            ['An acquirer', 'Stored data', 'Merger, acquisition, or asset sale, subject to this policy'],
          ]}
        />
        <p>
          Service providers may process data only on our instructions and may not use it for their own purposes.
        </p>
        <p>
          If you share your Hamme link on a social platform, that platform’s own privacy policy governs your post there.
          We do not control it.
        </p>

        <h2>6. How Long We Keep Information</h2>
        <LegalTable
          columns={['Data', 'Retention']}
          rows={[
            ['Account data (name, date of birth, photo, handle)', 'Until you delete your account'],
            ['Reactions and matches', 'Until you delete your account, or 12 months, whichever is sooner'],
            ['Web responder data (Section 3)', '90 days'],
            ['Diagnostic and crash logs', '90 days'],
            [
              'Abuse, ban, and moderation records',
              '12 months after account deletion, to stop banned users returning',
            ],
            ['Records we must keep by law', 'As long as the law requires'],
          ]}
        />
        <p>
          After an account is deleted, we delete or irreversibly anonymise the data above within 30 days, except where a
          longer period is listed.
        </p>

        <h2>7. Deleting Your Data</h2>
        <p>
          <strong>In the app:</strong> Settings → Delete Account. This removes your account and the data in Section 6.
        </p>
        <p>
          <strong>Without the app installed:</strong> email <MailLink email={legal.supportEmail} /> from a device or
          address we can verify. We will confirm and act within 30 days.
        </p>
        <p>You do not need to reinstall the app to request deletion.</p>

        <h2>8. Your Rights</h2>
        <p>
          Depending on where you live, you may have the right to access the information we hold about you, correct it,
          delete it, obtain a portable copy, object to or restrict certain processing, withdraw consent, and not be
          discriminated against for exercising these rights.
        </p>
        <ul>
          <li>
            <strong>India (DPDP Act, 2023):</strong> you may access, correct, and erase your data, nominate another
            person to exercise your rights, and raise a grievance. Our Grievance Officer is reachable at{' '}
            <MailLink email={legal.supportEmail} />. If unresolved, you may complain to the Data Protection Board of
            India.
          </li>
          <li>
            <strong>EU/UK (GDPR):</strong> you may also lodge a complaint with your local supervisory authority.
          </li>
          <li>
            <strong>California and other US states:</strong> you may exercise the rights above by contacting us. We do
            not sell personal information or share it for cross-context behavioural advertising, and we do not offer
            financial incentives for data.
          </li>
        </ul>
        <p>
          To exercise any right, email <MailLink email={legal.supportEmail} />. We will verify your request and respond
          within the period the applicable law allows.
        </p>

        <h2>9. Children and Teenagers</h2>
        <p>
          The Service is for users aged 13 and over. We do not knowingly collect personal information from children
          under 13. If we learn that we have, we delete the account and its data.
        </p>
        <p>
          In some jurisdictions, Apple and Google are required to verify a user’s age and obtain verifiable parental or
          guardian consent before a person under 18 downloads the app or makes a purchase. Where we receive an age
          category or consent signal from an app store, we may use it to confirm eligibility, to limit features, or to
          decline service. We use any such signal only for that purpose and delete it once used, where the law
          requires.
        </p>
        <p>
          If you are a parent or guardian and believe your child has provided information to us, contact{' '}
          <MailLink email={legal.supportEmail} /> and we will review and remove it.
        </p>

        <h2>10. Security</h2>
        <p>
          We protect information using encryption in transit (HTTPS/TLS), access controls limiting who on our side can
          reach production data, encrypted storage provided by our database host, hashing of account credentials, and
          rate limiting to prevent abuse. No system is completely secure, so we cannot guarantee absolute security. If
          a breach affects your personal data, we will notify you and the relevant authorities where the law requires.
        </p>

        <h2>11. International Transfers</h2>
        <p>
          We are based in India, and our users include people outside India. Your information may be stored and
          processed in India, the United States, and other countries where our providers operate, where data
          protection laws may differ from those where you live. Where required, we use appropriate safeguards such as
          standard contractual clauses with our providers.
        </p>

        <h2>12. Changes to This Policy</h2>
        <p>
          We may update this policy. If a change materially affects how we handle your information, we will notify you
          in the app or by a notice on our website at least 14 days before it takes effect. The “Last updated” date
          above always reflects the current version. Continued use after a change takes effect means you accept it.
        </p>

        <h2>13. Contact</h2>
        <p>
          Hamme
          <br />
          Privacy enquiries: <MailLink email={legal.supportEmail} />
          <br />
          Grievance Officer (India): <MailLink email={legal.supportEmail} />
        </p>
        <p>We aim to respond to privacy requests within 30 days.</p>

        <div className="mt-12 border-t border-white/10 pt-6 flex flex-wrap gap-4 text-sm text-white/60 justify-center">
          <a href="/support" className="hover:text-white transition">Support Center</a>
          <span>•</span>
          <a href="/terms-of-service" className="hover:text-white transition">Terms of Service</a>
          <span>•</span>
          <a href="/" className="hover:text-white transition">Home</a>
        </div>
      </section>
    </main>
  );
}

function SupportPage() {
  const [openFaq, setOpenFaq] = useState(null);

  const faqs = [
    {
      q: "What is Hamme?",
      a: "Hamme is a social app that lets you find out what your friends, crushes, and frenemies really think of you anonymously."
    },
    {
      q: "Is it really anonymous?",
      a: "Yes! All responses sent via your profile link are completely anonymous. We do not share your identity, device details, or IP address with the link owner unless you match."
    },
    {
      q: "How does matching work?",
      a: "If you send a 'Crush' or 'Friend' reaction to someone, and they send the same reaction back to you, it's a match! You'll be notified inside the mobile app to reveal each other's identity."
    },
    {
      q: "How do I reveal who voted?",
      a: "You can use the Reveal option in the mobile app to get clues or unlock the identity of your anonymous responses."
    },
    {
      q: "Can I delete my account and data?",
      a: "Absolutely. You can delete your account at any time directly from the settings menu inside the mobile app. This immediately purges all your personal information, links, and responses from our servers permanently."
    },
    {
      q: "I purchased Pro but it's not showing up. What should I do?",
      a: "Please make sure you are signed in with the same Apple ID or Google Play Account used for the purchase. Open the Pro subscription screen in the app and tap 'Restore Purchases'."
    },
    {
      q: "How do I report abusive behavior?",
      a: "We take safety and moderation very seriously. You can block users or report offensive responses directly in the app. You can also contact our support team at support@hamme.app with details."
    },
    {
      q: "How can I share my link?",
      a: "Copy your unique share link from the app's home screen and paste it into your Instagram bio, Snapchat story (using the link sticker), or send it directly to your friends!"
    }
  ];

  return (
    <main className="privacy-shell">
      <section className="privacy-card">
        <div className="privacy-eyebrow">Hamme</div>
        <h1>Support Center</h1>
        <p className="privacy-meta">How can we help you today?</p>

        <div className="my-8 rounded-2xl border border-white/10 bg-white/5 p-6">
          <h2 className="!mt-0 text-xl font-bold text-pink-300">1. Contact Us</h2>
          <p className="mt-2 text-white/90">
            Have questions, feedback, or need help with your account? Get in touch with our team:
          </p>
          <div className="mt-4">
            <a 
              href="mailto:support@hamme.app" 
              className="inline-flex items-center gap-2 rounded-xl bg-white px-5 py-3 font-extrabold text-black shadow-md hover:bg-white/95 transition active:scale-95"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              Email Support: support@hamme.app
            </a>
          </div>
        </div>

        <h2 className="text-xl font-bold text-pink-300">2. Frequently Asked Questions</h2>
        <div className="mt-4 flex flex-col gap-3">
          {faqs.map((faq, index) => {
            const isOpen = openFaq === index;
            return (
              <div 
                key={index} 
                className="overflow-hidden rounded-xl border border-white/10 bg-white/[0.02]"
              >
                <button
                  onClick={() => setOpenFaq(isOpen ? null : index)}
                  className="flex w-full items-center justify-between px-5 py-4 text-left font-bold text-white hover:bg-white/5 transition"
                >
                  <span>{faq.q}</span>
                  <svg 
                    className={`h-5 w-5 text-white/60 transition-transform duration-200 ${isOpen ? 'rotate-180' : ''}`} 
                    fill="none" 
                    stroke="currentColor" 
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                {isOpen && (
                  <div className="border-t border-white/5 px-5 py-4 text-white/80 leading-relaxed">
                    {faq.a}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        <div className="mt-12 border-t border-white/10 pt-6 flex flex-wrap gap-4 text-sm text-white/60 justify-center">
          <a href="/privacy-policy" className="hover:text-white transition">Privacy Policy</a>
          <span>•</span>
          <a href="/terms-of-service" className="hover:text-white transition">Terms of Service</a>
          <span>•</span>
          <a href="/" className="hover:text-white transition">Home</a>
        </div>
      </section>
    </main>
  );
}

function TermsOfServicePage() {
  return (
    <main className="privacy-shell">
      <section className="privacy-card">
        <div className="privacy-eyebrow">Hamme</div>
        <h1>Terms of Service</h1>
        <p className="privacy-meta">Last updated: {legal.lastUpdated}</p>
        <p>
          These Terms of Service (“Terms”) are a binding agreement between you and Hamme (“we”, “us”, “our”). They
          govern your use of the Hamme mobile application, the Hamme website and response pages, and all related
          services (together, the “Service”).
        </p>
        <p>
          By downloading the app, creating an account, responding on a Hamme link, or otherwise using the Service, you
          agree to these Terms and to our Privacy Policy at{' '}
          <a className="legal-link" href="/privacy-policy">www.hamme.app/privacy-policy</a>. If you do not agree, do not
          use the Service.
        </p>

        <h2>1. What Hamme Is</h2>
        <p>
          Hamme lets you share a link to your social media. People who open that link choose one of a small set of fixed
          reactions describing how they see you. You then see those reactions as cards in the app and choose a fixed
          reaction in return. Where both people choose the same reaction, we tell you both that you matched.
        </p>
        <p>
          The Service does not include free-text messaging. Participants cannot write, send, or transmit custom text,
          images, audio, video, or links to you through the Service. The only input a participant can give is a
          selection from the fixed options we provide.
        </p>
        <p>
          Some reactions appear without a sender name, because the person who sent them responded on the web and has not
          created a Hamme account. A name is attached only when that person creates an account and we can identify them.
          We describe this more fully in our <a className="legal-link" href="/privacy-policy">Privacy Policy</a>.
        </p>

        <h2>2. Eligibility and Age Requirements</h2>
        <p>
          You must be at least 13 years old to use the Service. The Service is not directed to children under 13, and we
          do not knowingly permit them to create accounts or submit reactions.
        </p>
        <p>
          If you are between 13 and 17, you may use the Service only where your parent or legal guardian permits it, and
          only where applicable law allows. In certain jurisdictions, app store operators such as Apple and Google are
          required to verify your age and obtain verifiable parental or guardian consent before you download the app or
          make a purchase. Where we receive an age category or consent signal from an app store, we may rely on it,
          restrict features, or decline to provide the Service to you.
        </p>
        <p>
          By using the Service you represent that you meet the age requirement, that any consent required for your use
          has been given, and that you have the legal capacity to enter into these Terms.
        </p>
        <p>
          We may terminate any account we believe belongs to a person below the minimum age, or to a minor without the
          required consent.
        </p>

        <h2>3. Your Account</h2>
        <p>
          You are responsible for the information you provide, for keeping access to your account secure, and for
          everything that happens under your account. Tell us at <MailLink email={legal.supportEmail} /> immediately if
          you believe your account has been accessed without your permission.
        </p>
        <p>
          You must provide accurate information. You must not create an account impersonating another person, create an
          account on someone else’s behalf without authority, or operate more than one account to evade a suspension or
          to manipulate reactions.
        </p>

        <h2>4. Prohibited Conduct</h2>
        <p>You must not use the Service to:</p>
        <ul>
          <li>harass, bully, abuse, stalk, threaten, intimidate, defame, or degrade any person;</li>
          <li>
            upload a profile photo that is not of you, that shows a person who has not consented, that shows a minor
            inappropriately, or that is sexual, violent, hateful, or otherwise objectionable;
          </li>
          <li>impersonate any person or misrepresent your identity or affiliation;</li>
          <li>
            solicit, share, or attempt to obtain sexual content, or use the Service for any sexual purpose involving a
            minor;
          </li>
          <li>artificially inflate, manipulate, automate, or purchase reactions, matches, or installs;</li>
          <li>
            scrape, crawl, reverse engineer, decompile, or attempt to extract source code or user data from the Service;
          </li>
          <li>interfere with, overload, or attempt to compromise the security or integrity of the Service;</li>
          <li>use the Service for any unlawful purpose or in violation of any applicable law.</li>
        </ul>
        <p>
          We have zero tolerance for objectionable content and abusive behaviour. Accounts that breach this section may
          be suspended or terminated without notice and without refund.
        </p>

        <h2>5. Reporting, Blocking, and Moderation</h2>
        <p>
          You can report any profile, photo, or reaction from within the app, and you can block any account so that it
          cannot appear to you or interact with you.
        </p>
        <p>
          We review reports and act on them promptly, and we aim to respond to reports of objectionable content within 24
          hours. Depending on what we find, we may remove content, restrict features, suspend an account, terminate an
          account, or report the matter to law enforcement.
        </p>
        <p>
          We may also use automated filtering and manual review to detect prohibited content, including on profile
          photos, before or after it is visible to others. We are not obliged to monitor all activity, but where we
          become aware of content or conduct that breaches these Terms, we will take appropriate action.
        </p>
        <p>
          You can also report abuse directly to <MailLink email={legal.supportEmail} />.
        </p>

        <h2>6. Your Content and the Licence You Give Us</h2>
        <p>
          “Your Content” means the information you submit to the Service, including your name, date of birth, profile
          photo, social media handle, and the reactions you select.
        </p>
        <p>
          You keep ownership of Your Content. You grant us a worldwide, non-exclusive, royalty-free, sublicensable
          licence to host, store, reproduce, adapt for display, and transmit Your Content solely to operate, provide,
          secure, and improve the Service. This licence ends when you delete the content or your account, except where
          we must retain it under Section 12 or applicable law, and except for copies already shared with other users.
        </p>
        <p>
          You represent that you have the rights necessary to grant this licence, and that Your Content does not infringe
          anyone’s rights or breach any law.
        </p>

        <h2>7. Our Intellectual Property</h2>
        <p>
          The Service, including the Hamme name, logo, app design, interface, features, reaction mechanics, and all
          software, is owned by us or our licensors and protected by intellectual property laws. These Terms grant you a
          limited, personal, non-exclusive, non-transferable, revocable licence to use the Service for your own personal,
          non-commercial use. No other rights are granted.
        </p>

        <h2>8. Intellectual Property Complaints</h2>
        <p>
          If you believe content on the Service infringes your intellectual property rights, contact{' '}
          <MailLink email={legal.supportEmail} /> with a description of the work, the location of the allegedly
          infringing content, your contact details, and a statement that you believe in good faith that the use is
          unauthorised. We will investigate and may remove content and terminate repeat infringers.
        </p>

        <h2>9. Third-Party Services</h2>
        <p>
          The Service works with third parties, including the Apple App Store, Google Play, social platforms such as
          Instagram and Snapchat, and attribution and analytics providers. Sharing a Hamme link to a social platform is
          subject to that platform’s own terms, and we do not control how that platform handles your post or your data.
          We are not responsible for third-party services, and their availability or changes to their APIs may affect
          the Service.
        </p>

        <h2>10. Purchases and Subscriptions</h2>
        <p>
          We may offer paid features. Prices are shown before purchase. Purchases and subscriptions are processed by the
          Apple App Store or Google Play and are governed by that store’s terms and refund policies. Subscriptions renew
          automatically unless cancelled through your store account before the renewal date. We do not process payments
          and cannot issue refunds directly; refund requests must go to Apple or Google. To the extent permitted by law,
          purchased virtual features are licensed, not sold, and have no cash value.
        </p>

        <h2>11. Changes to the Service</h2>
        <p>
          We may add, change, suspend, or discontinue any part of the Service, including removing features or changing
          how reactions and matches work. Where a change materially reduces what you have paid for, we will give
          reasonable notice or a pro-rated refund where required by law.
        </p>

        <h2>12. Deletion, Suspension, and Termination</h2>
        <p>
          You can delete your account at any time from the app’s settings. You can also request deletion, without
          reinstalling the app, by emailing <MailLink email={legal.supportEmail} /> from your registered address.
        </p>
        <p>
          When you delete your account, we delete or anonymise your personal data as described in the{' '}
          <a className="legal-link" href="/privacy-policy">Privacy Policy</a>. We may retain limited records where we
          are required to by law, or where necessary to resolve disputes, enforce these Terms, prevent fraud, or protect
          other users’ safety.
        </p>
        <p>
          We may suspend or terminate your access if you breach these Terms, if we are required to by law, or if we
          reasonably believe your use poses a risk to other users or to us. Where practical and lawful, we will tell you
          why.
        </p>

        <h2>13. Disclaimers</h2>
        <p>
          The Service is provided “as is” and “as available”. To the fullest extent permitted by law, we disclaim all
          warranties, express or implied, including merchantability, fitness for a particular purpose, and
          non-infringement. We do not warrant that the Service will be uninterrupted, error-free, or secure, or that
          reactions you receive are accurate, sincere, or from any particular person.
        </p>
        <p>
          Nothing in these Terms excludes or limits any warranty or right that cannot be excluded or limited under
          applicable law, including consumer protection law.
        </p>

        <h2>14. Limitation of Liability</h2>
        <p>
          To the fullest extent permitted by law, we will not be liable for any indirect, incidental, special,
          consequential, punitive, or exemplary damages, or for loss of profits, goodwill, data, or reputation, arising
          from or relating to your use of the Service.
        </p>
        <p>
          To the fullest extent permitted by law, our total aggregate liability for all claims relating to the Service
          will not exceed the greater of (a) the amount you paid us in the twelve months before the claim arose, or (b)
          INR 5,000.
        </p>
        <p>
          These limits do not apply to liability that cannot be limited under applicable law, including for death or
          personal injury caused by negligence, fraud, or wilful misconduct.
        </p>

        <h2>15. Indemnity</h2>
        <p>
          To the extent permitted by law, you agree to indemnify and hold us harmless from claims, damages, losses, and
          reasonable legal costs arising from Your Content, your breach of these Terms, or your unlawful use of the
          Service.
        </p>

        <h2>16. Governing Law and Disputes</h2>
        <p>
          These Terms are governed by the laws of India, without regard to conflict-of-laws rules. Any dispute will be
          subject to the exclusive jurisdiction of the courts of India.
        </p>
        <p>
          If you are a consumer resident elsewhere, nothing in this section deprives you of the protection of mandatory
          consumer laws of your country of residence, or of the right to bring proceedings in your local courts where
          applicable law gives you that right.
        </p>

        <h2>17. Changes to These Terms</h2>
        <p>
          We may update these Terms. If a change is material, we will give notice in the app or by email at least 14
          days before it takes effect, unless a shorter period is required by law or necessary for security or legal
          reasons. Continued use after a change takes effect means you accept the updated Terms. The “Last updated” date
          above always reflects the current version.
        </p>

        <h2>18. General</h2>
        <p>
          These Terms, together with the Privacy Policy, are the entire agreement between us regarding the Service. If
          any provision is found unenforceable, the rest remains in force and the unenforceable part will be limited to
          the minimum extent necessary. Our failure to enforce a provision is not a waiver of it. You may not assign these
          Terms; we may assign them in connection with a merger, acquisition, or sale of assets, on notice to you.
        </p>

        <h2>19. Contact</h2>
        <p>
          Hamme
          <br />
          Email: <MailLink email={legal.supportEmail} />
        </p>
        <p>
          We aim to respond to all enquiries within 5 business days, and to reports of objectionable content within 24
          hours.
        </p>

        <div className="mt-12 border-t border-white/10 pt-6 flex flex-wrap gap-4 text-sm text-white/60 justify-center">
          <a href="/support" className="hover:text-white transition">Support Center</a>
          <span>•</span>
          <a href="/privacy-policy" className="hover:text-white transition">Privacy Policy</a>
          <span>•</span>
          <a href="/" className="hover:text-white transition">Home</a>
        </div>
      </section>
    </main>
  );
}

function QuestionScreen({ onAnswer, profileImage, profileName, submittingType, submitError }) {
  return (
    <>
      <div className="flex w-full flex-col items-center px-6">
        <div className="relative z-10 h-[98px] w-[98px] overflow-hidden rounded-full border-[5px] border-white bg-[#d8b09f] shadow-[0_7px_14px_rgba(0,0,0,0.22)]">
          <img
            src={profileImage}
            alt="Profile"
            className="h-full w-full object-cover"
          />
        </div>

        <div className="mt-[10px] flex h-[37px] w-full items-center justify-center rounded-xl bg-white px-4 text-[19px] font-black tracking-[0.01em] text-black shadow-[0_7px_0_rgba(0,0,0,0.18)]">
          What do you think of me?
        </div>

        <p className="mt-4 text-[14px] font-medium text-white/95">🙈 Send anonymously</p>

        <div className="mt-[10px] flex w-full flex-col gap-[10px]">
          <button onClick={() => onAnswer('friend')} disabled={!!submittingType} className="h-[48px] rounded-2xl bg-[linear-gradient(90deg,#16c9e9,#0569f9)] text-[17px] font-extrabold shadow-[0_7px_0_rgba(0,0,0,0.18)] transition active:translate-y-1 active:shadow-[0_3px_0_rgba(0,0,0,0.18)] disabled:opacity-60">
            🤝 Friend
          </button>
          <button onClick={() => onAnswer('crush')} disabled={!!submittingType} className="h-[48px] rounded-2xl bg-[linear-gradient(90deg,#d14ce6,#ff3c98)] text-[17px] font-extrabold shadow-[0_7px_0_rgba(0,0,0,0.18)] transition active:translate-y-1 active:shadow-[0_3px_0_rgba(0,0,0,0.18)] disabled:opacity-60">
           😍 Crush
          </button>
          <button onClick={() => onAnswer('frenemy')} disabled={!!submittingType} className="h-[48px] rounded-2xl bg-[linear-gradient(90deg,#b7a7ee,#58598f)] text-[17px] font-extrabold shadow-[0_7px_0_rgba(0,0,0,0.18)] transition active:translate-y-1 active:shadow-[0_3px_0_rgba(0,0,0,0.18)] disabled:opacity-60">
            😈 Frenemy 
          </button>
          {submitError ? <p className="text-xs text-red-200">{submitError}</p> : null}
        </div>

      </div>
    </>
  );
}

function RevealScreen({
  secondsLeft,
  isExpired,
  profileName,
  profileImage,
  isMatch,
  pendingToken,
  shareCode,
  selectedType,
}) {
  const [copyStatus, setCopyStatus] = useState('');

  const buildFlutterWebFallbackUrl = () => {
    if (!flutterWebBaseUrl) {
      return '';
    }

    const base = flutterWebBaseUrl.replace(/\/+$/, '');
    return `${base}/#/home`;
  };

  const handleCopyDeepLink = async () => {
    const deepLink = buildDeepLink({ shareCode, type: selectedType, token: pendingToken });
    try {
      await navigator.clipboard.writeText(deepLink);
    } catch {
      const textarea = document.createElement('textarea');
      textarea.value = deepLink;
      textarea.setAttribute('readonly', '');
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
    }
    setCopyStatus('Copied deeplink');
  };

  const handleReveal = async () => {
    if (!pendingToken && !shareCode) return;

    if (pendingToken) {
      try {
        await fetch(`${apiBaseUrl}/interactions/pending/${pendingToken}/touch`, { method: 'POST' });
      } catch {
      }
    }

    const userAgent = navigator.userAgent || navigator.vendor || window.opera;
    const isAndroid = /android/i.test(userAgent);
    const isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;

    const deepLink = buildDeepLink({ shareCode, type: selectedType, token: pendingToken });

    const referrerParams = new URLSearchParams();
    if (pendingToken) referrerParams.set('hamme_token', pendingToken);
    if (shareCode) referrerParams.set('hamme_code', shareCode);
    if (selectedType) referrerParams.set('hamme_type', selectedType);

    const playStoreUrl = `https://play.google.com/store/apps/details?id=com.hamme.app&referrer=${encodeURIComponent(referrerParams.toString())}`;
    const appStoreUrl = import.meta.env.VITE_APP_STORE_URL ?? '';

    window.location.href = deepLink;

    console.info('[Web] deep link triggered', { deepLink });

    setTimeout(() => {
      if (document.visibilityState === 'visible') {
        if (isAndroid) {
          window.location.href = playStoreUrl;
        } else if (isIOS && appStoreUrl) {
          window.location.href = appStoreUrl;
        }
      }
    }, 2500);
  };

  return (
    <div className="w-full">
      <div className="mx-auto flex h-[25px] w-[96px] items-center justify-center rounded-full border border-white/80 bg-white/10 text-[18px] font-extrabold">
        <span className="relative mr-[7px] h-[19px] w-[19px] shrink-0 overflow-hidden">
          <img
            src="/tic.png"
            alt=""
            className="absolute left-1/2 top-1/2 h-[48px] w-[48px] max-w-none -translate-x-1/2 -translate-y-1/2"
          />
        </span>
        Sent!
      </div>

      <div className="mt-[40px] text-[15px] font-medium text-white/70">
        {isMatch ? "It's a match!" : 'Your response was sent anonymously'}
      </div>
      <div className="mt-2 text-[15px] font-medium text-white/70">Now the question is -</div>
      <h1 className="mx-auto mt-2 max-w-[285px] text-[31px] font-black leading-[1.38] tracking-[-0.02em]">
        What does
        <span className="mx-[8px] inline-flex h-[38px] w-[38px] translate-y-[7px] overflow-hidden rounded-full border-2 border-white bg-[#d8b09f] align-baseline">
          <img src={profileImage} alt={profileName} className="h-full w-full object-cover" />
        </span>
        {profileName}
        <br />
        think of you?
      </h1>

      <div className="mt-[51px] px-4">
        <div className="mb-[6px] flex items-center justify-between text-[11px] font-black text-white/65">
          <span>{isExpired ? 'LINK EXPIRED' : 'LINK EXPIRES IN'}</span>
          <span className={secondsLeft <= 20 ? 'text-[#ff4545]' : 'text-white'}>{String(secondsLeft).padStart(2, '0')}s</span>
        </div>
        <div className="h-[3px] overflow-hidden rounded-full bg-white/35">
          <div
            className={`h-full rounded-full ${secondsLeft <= 20 ? 'bg-[#ff4545]' : 'bg-white'}`}
            style={{ width: `${(secondsLeft / pendingTtlSeconds) * 100}%` }}
          />
        </div>
      </div>

      <button
        onClick={handleReveal}
        disabled={isExpired}
        className="reveal-button mt-[12px] flex h-[61px] w-full items-center justify-center rounded-[27px] bg-white px-8 text-[20px] font-black text-[#c000df] shadow-[0_7px_0_rgba(0,0,0,0.10)] transition active:translate-y-1 disabled:cursor-not-allowed disabled:opacity-40 disabled:shadow-none disabled:active:translate-y-0"
      >
        <span className="flex-1">{isExpired ? 'Link Expired' : 'Reveal'}</span>
        {!isExpired && <span className="text-[27px] font-light">{"->"}</span>}
      </button>

      {/* <button
        onClick={handleCopyDeepLink}
        disabled={isExpired || !pendingToken}
        className="mt-[12px] flex h-[50px] w-full items-center justify-center rounded-[22px] bg-white/15 text-[16px] font-extrabold text-white disabled:opacity-45"
      >
        Copy Deeplink
      </button> */}
      {copyStatus ? (
        <p className="mt-2 text-[12px] font-bold text-white/75">{copyStatus}</p>
      ) : null}
    </div>
  );
}

function AlreadyVotedScreen({ profileName, profileImage }) {
  return (
    <div className="w-full">
      <div className="mx-auto flex h-[25px] w-[96px] items-center justify-center rounded-full border border-white/80 bg-white/10 text-[18px] font-extrabold">
        <span className="relative mr-[7px] h-[19px] w-[19px] shrink-0 overflow-hidden">
          <img
            src="/tic.png"
            alt=""
            className="absolute left-1/2 top-1/2 h-[48px] w-[48px] max-w-none -translate-x-1/2 -translate-y-1/2"
          />
        </span>
        Sent!
      </div>
      <div className="mt-[40px] flex flex-col items-center gap-3">
        <div className="relative z-10 h-[80px] w-[80px] overflow-hidden rounded-full border-[4px] border-white bg-[#d8b09f] shadow-[0_7px_14px_rgba(0,0,0,0.22)]">
          <img src={profileImage} alt="Profile" className="h-full w-full object-cover" />
        </div>
        <h2 className="text-[24px] font-black leading-tight">You already voted!</h2>
        <p className="max-w-[260px] text-[15px] font-medium text-white/70">
          You already sent your reaction to <strong>{profileName}</strong>. You can vote for them again after 24 hours.
        </p>
      </div>
    </div>
  );
}

export default App;
