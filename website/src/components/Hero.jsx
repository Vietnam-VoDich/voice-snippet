import { motion } from 'framer-motion';
import { Download, Sparkles } from 'lucide-react';

function GithubIcon({ size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
    </svg>
  );
}

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 24 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.6, delay, ease: [0.16, 1, 0.3, 1] },
});

export default function Hero() {
  return (
    <section className="section-padding hero-grid" style={{ minHeight: 'auto', paddingTop: 'clamp(40px, 8vw, 100px)', paddingBottom: 'clamp(40px, 8vw, 80px)' }}>
      {/* Text column */}
      <div className="hero-copy">
        <motion.div {...fadeUp(0)}>
          <span className="eyebrow">
            <Sparkles size={12} style={{ marginRight: 6 }} />
            Mac App &middot; Local-First &middot; Open Source
          </span>
        </motion.div>

        <motion.h1 {...fadeUp(0.1)}>
          Capture the thought before it evaporates.
        </motion.h1>

        <motion.p
          {...fadeUp(0.2)}
          className="hero-lede"
          style={{ color: 'var(--muted)', fontSize: 'clamp(16px, 2vw, 19px)', marginBottom: 32, lineHeight: 1.65, maxWidth: 560 }}
        >
          A tiny floating Mac app that turns spoken thoughts into clean text. Press a shortcut, talk, and get a transcript on your clipboard &mdash; no cloud API, no sign-up.
        </motion.p>

        <motion.div
          {...fadeUp(0.3)}
          style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}
        >
          <a
            href="https://github.com/Vietnam-VoDich/voice-snippet/releases/latest"
            className="button primary"
          >
            <Download size={18} />
            Download for Mac
          </a>
          <a
            href="https://github.com/Vietnam-VoDich/voice-snippet"
            className="button secondary"
            target="_blank"
            rel="noopener noreferrer"
          >
            <GithubIcon size={18} />
            View on GitHub
          </a>
        </motion.div>

        <motion.p
          {...fadeUp(0.5)}
          style={{ marginTop: 20, fontSize: 13, color: 'var(--muted)', fontWeight: 500 }}
        >
          Apple Silicon Mac &middot; macOS 26+ &middot; Apple Intelligence for rewrite styles
        </motion.p>
      </div>

      {/* Visual column */}
      <motion.div
        className="hero-visual"
        initial={{ opacity: 0, scale: 0.96, y: 16 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 0.7, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className="demo-frame" style={{ padding: 3 }}>
          <video
            autoPlay
            loop
            muted
            playsInline
            style={{ width: '100%', borderRadius: 18, background: 'var(--soft)', display: 'block' }}
            poster="/assets/demo-start.png"
          >
            <source src="/assets/voice-snippet-demo.mp4" type="video/mp4" />
          </video>
        </div>
      </motion.div>
    </section>
  );
}
