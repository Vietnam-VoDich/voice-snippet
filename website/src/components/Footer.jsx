import { motion } from 'framer-motion';
import { ArrowUp, Shield, Wifi, Server } from 'lucide-react';
import { useEffect, useState } from 'react';

const INSTALL_STEPS = [
  'Download VoiceSnippet.app.zip from the latest GitHub release.',
  'Unzip it and drag VoiceSnippet.app into your Applications folder.',
  'Open the app and allow Microphone access when macOS asks.',
  'Record a short sentence, then use a rewrite style to clean it up.',
];

const PRIVACY_BADGES = [
  { icon: Shield, label: 'No account needed', color: 'var(--green)', bg: 'var(--green-light)' },
  { icon: Wifi, label: 'No API key', color: 'var(--amber)', bg: 'var(--amber-light)' },
  { icon: Server, label: 'No cloud transcription', color: 'var(--violet)', bg: 'var(--violet-light)' },
];

function BackToTop() {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const onScroll = () => setVisible(window.scrollY > 400);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);
  return (
    <button
      className={`back-to-top${visible ? ' visible' : ''}`}
      onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
      aria-label="Back to top"
    >
      <ArrowUp size={18} strokeWidth={2.5} />
    </button>
  );
}

export default function Footer() {
  return (
    <>
      {/* Privacy section */}
      <section id="privacy" className="section-padding" style={{ background: 'var(--soft)', borderTop: '1px solid var(--line)' }}>
        <div className="dot-grid" />
        <div className="content-max privacy-grid" style={{ position: 'relative', zIndex: 1 }}>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <span className="eyebrow">Privacy Model</span>
            <h2>No account. No API key. No cloud transcription.</h2>
            <div className="section-line" />
            <div className="privacy-badges">
              {PRIVACY_BADGES.map((b, i) => (
                <motion.div
                  key={b.label}
                  className="privacy-badge"
                  initial={{ opacity: 0, x: -12 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: i * 0.1, duration: 0.4 }}
                >
                  <span className="badge-icon" style={{ background: b.bg, color: b.color, borderRadius: 8, width: 24, height: 24, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <b.icon size={14} strokeWidth={2.2} />
                  </span>
                  {b.label}
                </motion.div>
              ))}
            </div>
          </motion.div>

          <motion.p
            className="lede"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.7 }}
          >
            Voice Snippet uses WhisperKit for speech-to-text and Apple Foundation Models for rewrite styles. The app makes one network request for first-run Whisper model download; daily transcription and formatting run entirely locally.
          </motion.p>
        </div>
      </section>

      {/* Install section */}
      <section id="install" className="section-padding" style={{ paddingBottom: 'clamp(80px, 10vw, 140px)' }}>
        <div className="content-max">
          <div className="glass-panel" style={{ padding: 'clamp(28px, 4vw, 48px)' }}>
            <span className="eyebrow">Install</span>
            <h2>Try it on a supported Mac.</h2>
            <div className="section-line" />

            <div className="install-steps">
              {INSTALL_STEPS.map((step, i) => (
                <motion.div
                  key={i}
                  className="step-card"
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: i * 0.1, duration: 0.45 }}
                >
                  <span className="step-num">{i + 1}</span>
                  <span>{step}</span>
                </motion.div>
              ))}
            </div>

            <div style={{ display: 'flex', gap: 12, marginTop: 36, flexWrap: 'wrap' }}>
              <a href="https://github.com/Vietnam-VoDich/voice-snippet/releases/latest" className="button primary">
                Get the latest release
              </a>
              <a href="https://github.com/Vietnam-VoDich/voice-snippet/issues" className="button secondary" target="_blank" rel="noopener noreferrer">
                Open issues
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Footer bar */}
      <footer className="site-footer">
        <span className="footer-brand">Voice Snippet</span>
        <a href="https://github.com/Vietnam-VoDich/voice-snippet/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">MIT License</a>
        <a href="https://github.com/Vietnam-VoDich/voice-snippet" target="_blank" rel="noopener noreferrer">GitHub</a>
      </footer>

      <BackToTop />
    </>
  );
}
