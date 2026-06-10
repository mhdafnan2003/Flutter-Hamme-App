import { useEffect, useState } from 'react';

const players = ['S', 'K', 'R', 'N', 'A'];
const fallbackProfileImage = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80';
const playerColors = ['#ff4f97', '#35d678', '#42b6ff', '#ffd230', '#ff5c5c'];
const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api/v1';
const flutterWebBaseUrl = import.meta.env.VITE_FLUTTER_WEB_URL ?? '';
const sessionStorageKey = 'hamme_web_session_id';
const pendingTtlMs = 60 * 1000;

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

function App() {
  const [isSent, setIsSent] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(60);
  const [expiresAt, setExpiresAt] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);
  const [profileError, setProfileError] = useState('');
  const [submittingType, setSubmittingType] = useState('');
  const [selectedType, setSelectedType] = useState('');
  const [submitError, setSubmitError] = useState('');
  const [interactionResult, setInteractionResult] = useState(null);
  const isExpired = secondsLeft === 0;
  const shareCode = readShareCodeFromPath();

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
          setSecondsLeft(Math.ceil(pendingTtlMs / 1000));
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
      setInteractionResult(data); // contains pendingToken
      setIsSent(true);
      if (data.expiresAt) {
        const expires = new Date(data.expiresAt);
        setExpiresAt(expires.toISOString());
        const remainingMs = expires.getTime() - Date.now();
        setSecondsLeft(Math.max(Math.ceil(remainingMs / 1000), 0));
      } else {
        const fallbackExpires = new Date(now + pendingTtlMs);
        setExpiresAt(fallbackExpires.toISOString());
        setSecondsLeft(Math.ceil(pendingTtlMs / 1000));
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
      <main className="min-h-screen bg-[linear-gradient(180deg,#9b63f7_0%,#8f48fa_48%,#7c35ff_100%)] text-white" >
        <section className="mx-auto flex min-h-screen w-full max-w-[360px] items-center justify-center px-4 text-center" >
          <p className="text-lg font-bold">{profileError || 'Profile unavailable.'}</p>
        </section>
      </main>
    );
  }

  const profileName = profile.name ?? 'User';
  const profileImage = profile.profileImageUrl || fallbackProfileImage;

  return (
    <main className="min-h-screen overflow-hidden bg-[linear-gradient(180deg,#9b63f7_0%,#8f48fa_48%,#7c35ff_100%)] text-white">
      <section className={`mx-auto flex min-h-screen w-full max-w-[360px] flex-col items-center px-4 pb-8 text-center ${isSent ? 'pt-[82px]' : 'pt-[132px]'}`}>
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
        ) : (
          <QuestionScreen
            onAnswer={handleAnswer}
            profileImage={profileImage}
            submittingType={submittingType}
            submitError={submitError}
          />
        )}

        <FriendsPlaying className={isSent ? 'mt-[29px]' : 'mt-[45px]'} />

        <footer className="mt-auto flex flex-col items-center">
          <h1 className="brand-text text-[28px] font-black leading-none tracking-[-0.06em]">Hamme</h1>
          <p className="mt-2 text-[12px] font-extrabold">play games &amp; meet people</p>
          <div className="mt-[28px] flex gap-4 text-[12px] font-bold text-white/45">
            <a href="#">Terms</a>
            <a href="#">Privacy</a>
          </div>
        </footer>
      </section>
    </main>
  );
}

function QuestionScreen({ onAnswer, profileImage, submittingType, submitError }) {
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

        <div className="-mt-[6px] flex h-[37px] w-full items-center justify-center rounded-xl bg-white px-4 text-[19px] font-black tracking-[0.01em] text-black shadow-[0_7px_0_rgba(0,0,0,0.18)]">
          What do you think of me?
        </div>

        <p className="mt-4 text-[14px] font-medium text-white/95">🙈 send anonymously</p>

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

  const buildDeepLink = () => {
    const params = new URLSearchParams();
    if (shareCode) params.set('code', shareCode);
    if (selectedType) params.set('type', selectedType);
    if (pendingToken) params.set('token', pendingToken);
    return `hamme://open?${params.toString()}`;
  };

  const buildFlutterWebFallbackUrl = () => {
    if (!flutterWebBaseUrl) {
      return '';
    }

    const base = flutterWebBaseUrl.replace(/\/+$/, '');
    return `${base}/#/home`;
  };

  const handleCopyDeepLink = async () => {
    const deepLink = buildDeepLink();
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

  const handleReveal = () => {
    if (!pendingToken && !shareCode) return;

    const userAgent = navigator.userAgent || navigator.vendor || window.opera;
    const isAndroid = /android/i.test(userAgent);
    const isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;

    const deepLink = buildDeepLink();
    
    const referrerParams = new URLSearchParams();
    if (pendingToken) referrerParams.set('hamme_token', pendingToken);
    if (shareCode) referrerParams.set('hamme_code', shareCode);
    if (selectedType) referrerParams.set('hamme_type', selectedType);

    const playStoreUrl = `https://play.google.com/store/apps/details?id=com.hamme.app&referrer=${encodeURIComponent(referrerParams.toString())}`;
    const appStoreUrl = 'https://apps.apple.com/app/hamme-play-games/id123456789';
    const fallbackUrl = buildFlutterWebFallbackUrl();

    window.location.href = deepLink;

    console.info('[Web] deep link triggered', { deepLink });

    // Redirect to store if app not installed (after a short delay)
    setTimeout(() => {
      if (document.visibilityState === 'visible') {
        if (isAndroid) {
          window.location.href = playStoreUrl;
        } else if (isIOS) {
          window.location.href = appStoreUrl;
        } else if (fallbackUrl) {
          window.location.href = fallbackUrl;
        }
      }
    }, 2500);
  };

  return (
    <div className="w-full">
      <div className="mx-auto flex h-[25px] w-[96px] items-center justify-center rounded-full border border-white/80 bg-white/10 text-[18px] font-extrabold">
        <span className="mr-[7px] flex h-[19px] w-[19px] items-center justify-center rounded-full bg-white text-[12px] text-[#9b55f7]">✓</span>
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
            style={{ width: `${(secondsLeft / 60) * 100}%` }}
          />
        </div>
      </div>

      <button
        onClick={handleReveal}
        className="mt-[12px] flex h-[61px] w-full items-center justify-center rounded-[27px] bg-white px-8 text-[20px] font-black text-[#c000df] shadow-[0_7px_0_rgba(0,0,0,0.10)] transition active:translate-y-1"
      >
        <span className="flex-1">👀 Reveal</span>
        <span className="text-[27px] font-light">→</span>
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

      {flutterWebBaseUrl ? (
        <a
          href={buildFlutterWebFallbackUrl()}
          className="mt-[12px] flex h-[50px] w-full items-center justify-center rounded-[22px] bg-white/15 text-[16px] font-extrabold text-white"
        >
          Continue In Web App
        </a>
      ) : null}
    </div>
  );
}

function FriendsPlaying({ className }) {
  return (
    <>
        <div className={`${className} flex items-center`}>
          <span className="mr-2 h-[10px] w-[10px] rounded-full bg-[#22ff00]" />
          <div className="flex">
            {players.map((player, index) => (
              <span
                key={player}
                className="flex h-[22px] w-[22px] items-center justify-center rounded-full border border-white/25 text-[12px] font-black text-white"
                style={{
                  marginLeft: index === 0 ? 0 : -4,
                  backgroundColor: playerColors[index],
                }}
              >
                {player}
              </span>
            ))}
          </div>
        </div>

        <p className="mt-[8px] text-[17px] font-extrabold tracking-[0.01em]">☝️ 6 friends playing now ☝️</p>
    </>
  );
}

export default App;
