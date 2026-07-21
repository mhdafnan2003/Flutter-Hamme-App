import { useEffect, useState } from 'react';

const fallbackProfileImage = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80';
const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api/v1';
const flutterWebBaseUrl = import.meta.env.VITE_FLUTTER_WEB_URL ?? '';
const sessionStorageKey = 'hamme_web_session_id';
const votedCodesKey = 'hamme_voted_codes';
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
    return Boolean(voted[code]);
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
  if (parts.length >= 2 && parts[0] === 'u') {
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
          <h1 className="brand-text text-[28px] font-black leading-none tracking-[-0.06em]">Hamme</h1>
          <p className="mt-2 text-[12px] font-extrabold">play games &amp; meet people</p>
        </footer>
      </section>
    </main>
  );
}

function PrivacyPolicyPage() {
  return (
    <main className="privacy-shell">
      <section className="privacy-card">
        <div className="privacy-eyebrow">Hamme</div>
        <h1>Privacy Policy</h1>
        <p className="privacy-meta">Last updated: June 27, 2026</p>
        <p>
          This Privacy Policy explains how Hamme collects, uses, stores, and shares information when you use the
          Hamme mobile application, related web pages, and connected services.
        </p>

        <h2>1. Information We Collect</h2>
        <p>We may collect the following categories of information:</p>
        <ul>
          <li>Account information such as your name, email address, username, Instagram ID, and profile image.</li>
          <li>Profile and app activity such as your share code, anonymous reactions, matches, and in-app interactions.</li>
          <li>Device and technical information such as app version, device type, browser type, IP address, and log data.</li>
          <li>Session and security data used to keep you signed in and protect the service from abuse or fraud.</li>
        </ul>

        <h2>2. How We Use Information</h2>
        <ul>
          <li>To create and manage your account.</li>
          <li>To deliver core app features, including profile sharing, anonymous responses, and match-related experiences.</li>
          <li>To maintain service performance, security, and reliability.</li>
          <li>To troubleshoot bugs, prevent misuse, and improve the app.</li>
          <li>To comply with legal obligations and enforce our terms.</li>
        </ul>

        <h2>3. How Anonymous Interactions Work</h2>
        <p>
          Hamme allows users to send responses through shared profile links. Those responses are processed by our
          backend to power app features such as anonymous reactions and match detection. Public profile pages are
          designed not to expose private account details like a user&apos;s email address.
        </p>

        <h2>4. Sharing of Information</h2>
        <p>We do not sell your personal information. We may share information only in the following situations:</p>
        <ul>
          <li>With service providers or infrastructure partners that help us operate the app.</li>
          <li>When required by law, regulation, legal process, or government request.</li>
          <li>To protect the rights, safety, security, and integrity of Hamme, our users, or the public.</li>
          <li>As part of a business transfer such as a merger, acquisition, or asset sale.</li>
        </ul>

        <h2>5. Data Retention</h2>
        <p>
          We retain information for as long as needed to provide the service, maintain security, resolve disputes,
          enforce agreements, and meet legal requirements. Retention periods may vary depending on the type of data and
          how it is used.
        </p>

        <h2>6. Data Security</h2>
        <p>
          We use reasonable technical and organizational measures to protect information. No method of transmission or
          storage is completely secure, so we cannot guarantee absolute security.
        </p>

        <h2>7. Your Choices</h2>
        <ul>
          <li>You can choose what profile details you provide within the app.</li>
          <li>You may request account-related help, updates, or deletion support through our contact channel.</li>
          <li>You can stop using the app at any time, subject to any data we must retain for legal or security reasons.</li>
        </ul>

        <h2>8. Children&apos;s Privacy</h2>
        <p>
          Hamme is not intended for children under 13, and we do not knowingly collect personal information from
          children under 13. If you believe a child has provided personal information, contact us so we can review and
          remove it where appropriate.
        </p>

        <h2>9. International Data Processing</h2>
        <p>
          Your information may be processed and stored in countries other than your own, where data protection laws may
          differ from those in your jurisdiction.
        </p>

        <h2>10. Changes to This Policy</h2>
        <p>
          We may update this Privacy Policy from time to time. When we do, we will update the date at the top of this
          page. Continued use of the app after an update means you accept the revised policy.
        </p>

        <h2>11. Contact Us</h2>
        <p>
          For privacy questions or requests, contact the Hamme team at support@hamme.app.
        </p>

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
        <p className="privacy-meta">Last updated: June 27, 2026</p>
        <p>
          Welcome to Hamme. These Terms of Service (&quot;Terms&quot;) govern your use of the Hamme mobile application, 
          related web pages, and connected services (&quot;Service&quot;) provided by Hamme. By accessing or using the 
          Service, you agree to be bound by these Terms.
        </p>

        <h2>1. Acceptance of Terms</h2>
        <p>
          By creating an account, sending responses, or using any part of the Service, you agree to these Terms and 
          our Privacy Policy. If you do not agree, you must not access or use the Service.
        </p>

        <h2>2. Eligibility</h2>
        <p>
          You must be at least 13 years old to use the Service. By using the Service, you represent and warrant that 
          you meet this age requirement and have the legal capacity to enter into this agreement.
        </p>

        <h2>3. User Accounts</h2>
        <p>
          You are responsible for maintaining the confidentiality of your account credentials and for all activities 
          that occur under your account. You agree to notify us immediately of any unauthorized use of your account.
        </p>

        <h2>4. User Conduct & Content</h2>
        <p>
          You agree not to use the Service to:
        </p>
        <ul>
          <li>Harass, abuse, stalk, threaten, defame, or otherwise violate the rights of others.</li>
          <li>Post or transmit any content that is hateful, offensive, obscene, or discriminatory.</li>
          <li>Send spam, fraudulent links, or unauthorized commercial communications.</li>
          <li>Attempt to compromise the security or integrity of the Service.</li>
        </ul>
        <p>
          We reserve the right to monitor, review, and remove any content or suspend/terminate accounts that violate 
          these guidelines.
        </p>

        <h2>5. Anonymous Interactions</h2>
        <p>
          Our Service allows users to receive anonymous feedback. You understand and agree that you may receive 
          messages or reactions from anonymous senders. Hamme is not responsible for the content of anonymous messages, 
          but we provide block, report, and moderation tools to help keep the platform safe.
        </p>

        <h2>6. In-App Purchases and Subscriptions</h2>
        <p>
          Hamme may offer paid premium services (like Pro features). Subscriptions and purchases are billed through 
          Apple App Store or Google Play Store. All purchases are governed by the respective store's terms, and refunds 
          must be requested directly from Apple or Google.
        </p>

        <h2>7. Account Deletion and Termination</h2>
        <p>
          You can delete your account at any time from the settings menu inside the mobile app. We may suspend or 
          terminate your access to the Service at our sole discretion, without notice, if you violate these Terms.
        </p>

        <h2>8. Disclaimers and Limitation of Liability</h2>
        <p>
          THE SERVICE IS PROVIDED &quot;AS IS&quot; WITHOUT WARRANTIES OF ANY KIND. IN NO EVENT SHALL HAMME BE LIABLE 
          FOR ANY INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF YOUR USE OF THE SERVICE.
        </p>

        <h2>9. Contact Us</h2>
        <p>
          If you have any questions about these Terms, please contact us at support@hamme.app.
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

        <p className="mt-4 text-[14px] font-medium text-white/95">Send anonymously</p>

        <div className="mt-[10px] flex w-full flex-col gap-[10px]">
          <button onClick={() => onAnswer('friend')} disabled={!!submittingType} className="h-[48px] rounded-2xl bg-[linear-gradient(90deg,#16c9e9,#0569f9)] text-[17px] font-extrabold shadow-[0_7px_0_rgba(0,0,0,0.18)] transition active:translate-y-1 active:shadow-[0_3px_0_rgba(0,0,0,0.18)] disabled:opacity-60">
            Friend
          </button>
          <button onClick={() => onAnswer('crush')} disabled={!!submittingType} className="h-[48px] rounded-2xl bg-[linear-gradient(90deg,#d14ce6,#ff3c98)] text-[17px] font-extrabold shadow-[0_7px_0_rgba(0,0,0,0.18)] transition active:translate-y-1 active:shadow-[0_3px_0_rgba(0,0,0,0.18)] disabled:opacity-60">
            Crush
          </button>
          <button onClick={() => onAnswer('frenemy')} disabled={!!submittingType} className="h-[48px] rounded-2xl bg-[linear-gradient(90deg,#b7a7ee,#58598f)] text-[17px] font-extrabold shadow-[0_7px_0_rgba(0,0,0,0.18)] transition active:translate-y-1 active:shadow-[0_3px_0_rgba(0,0,0,0.18)] disabled:opacity-60">
            Frenemy
          </button>
          {submitError ? <p className="text-xs text-red-200">{submitError}</p> : null}
        </div>

        <div className="mt-[28px] flex flex-col items-center">
          <div className="relative rounded-full bg-black px-5 py-2 text-[14px] font-black text-white">
            Tap to play
            <div className="absolute -bottom-[6px] left-1/2 h-0 w-0 -translate-x-1/2 border-l-[6px] border-r-[6px] border-t-[7px] border-l-transparent border-r-transparent border-t-black" />
          </div>
        </div>

        <div className="mt-[14px] flex h-[40px] items-center justify-center rounded-full bg-white px-5 shadow-[0_4px_12px_rgba(0,0,0,0.1)]">
          <span className="mr-2 text-[16px]">Link</span>
          <span className="text-[14px] font-black tracking-wide text-black">HAMME.LINK</span>
        </div>

        <div className="mt-[14px] flex items-center gap-6">
          <svg width="24" height="32" viewBox="0 0 24 32" fill="none"><path d="M12 30V4M12 4L4 13M12 4L20 13" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <svg width="24" height="32" viewBox="0 0 24 32" fill="none"><path d="M12 30V4M12 4L4 13M12 4L20 13" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <svg width="24" height="32" viewBox="0 0 24 32" fill="none"><path d="M12 30V4M12 4L4 13M12 4L20 13" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/></svg>
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
        <span className="mr-[7px] flex h-[19px] w-[19px] items-center justify-center rounded-full bg-white text-[12px] text-[#9b55f7]">OK</span>
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
        className="mt-[12px] flex h-[61px] w-full items-center justify-center rounded-[27px] bg-white px-8 text-[20px] font-black text-[#c000df] shadow-[0_7px_0_rgba(0,0,0,0.10)] transition active:translate-y-1 disabled:cursor-not-allowed disabled:opacity-40 disabled:shadow-none disabled:active:translate-y-0"
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
        <span className="mr-[7px] flex h-[19px] w-[19px] items-center justify-center rounded-full bg-white text-[12px] text-[#9b55f7]">OK</span>
        Sent!
      </div>
      <div className="mt-[40px] flex flex-col items-center gap-3">
        <div className="relative z-10 h-[80px] w-[80px] overflow-hidden rounded-full border-[4px] border-white bg-[#d8b09f] shadow-[0_7px_14px_rgba(0,0,0,0.22)]">
          <img src={profileImage} alt="Profile" className="h-full w-full object-cover" />
        </div>
        <h2 className="text-[24px] font-black leading-tight">You already voted!</h2>
        <p className="max-w-[260px] text-[15px] font-medium text-white/70">
          You already sent your reaction to <strong>{profileName}</strong>. Only one vote per person is allowed.
        </p>
      </div>
    </div>
  );
}

export default App;
