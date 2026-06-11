import { motion } from 'framer-motion';
import { ArrowUp } from 'lucide-react';
import { useEffect, useState } from 'react';

const INSTALL_STEPS = [
  'Download VoiceSnippet.app.zip from the latest GitHub release.',
  'Unzip it and drag VoiceSnippet.app into your Applications folder.',
  'Open the app and allow Microphone access when macOS asks.',
  'Record a short sentence, then use a rewrite style to clean it up.',
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
      <section id="privacy" className="section-padding" style={{ background: 'var(--panel)', borderTop: '1px solid var(--line)' }}>
        <div className="content-max privacy-grid">
          <div>
            <span className="eyebrow">Privacy Model</span>
            <h2>No account. No API key. No cloud transcription.</h2>
          </div>
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
        <a href="https://github.com/Vietnam-VoDich/voice-snippet/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">
          MIT License
        </a>
        <a href="https://github.com/Vietnam-VoDich/voice-snippet" target="_blank" rel="noopener noreferrer">
          GitHub
        </a>
      </footer>

      <BackToTop />
    </>
  );
}
