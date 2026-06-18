import { motion } from 'framer-motion';
import { Mic, Zap, Sparkles } from 'lucide-react';

const cardVariant = {
  hidden: { opacity: 0, y: 32 },
  visible: (i) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.55, delay: i * 0.12, ease: [0.16, 1, 0.3, 1] },
  }),
};

const FEATURES = [
  {
    icon: Mic,
    iconColor: 'blue',
    title: 'Record anywhere',
    desc: 'Press a global shortcut anywhere on your Mac to start recording. The floating widget stays out of your way while you work.',
  },
  {
    icon: Zap,
    iconColor: 'green',
    title: 'Transcribe locally',
    desc: 'WhisperKit runs fully on-device. Audio never leaves your Mac, and transcriptions are lightning fast after the first run.',
  },
  {
    icon: Sparkles,
    iconColor: 'violet',
    title: 'Clean up instantly',
    desc: 'Use on-device Apple Foundation Models to turn rough speech into clean notes, bullets, emails, or polished prose in one tap.',
  },
];

export default function Features() {
  return (
    <section className="section-padding" style={{ background: 'var(--soft)', borderTop: '1px solid var(--line)' }}>
      <div className="content-max">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.5 }}
          style={{ maxWidth: 800, marginBottom: 48 }}
        >
          <span className="eyebrow">Daily Flow</span>
          <h2>Built for the way you think.</h2>
          <div className="section-line" />
          <p style={{ fontSize: '1.05rem', color: 'var(--muted)', maxWidth: 640, lineHeight: 1.65, marginTop: 16 }}>
            Start from the floating widget or a global shortcut while you are writing, browsing, or moving between apps.
          </p>
        </motion.div>

        <div className="grid-3">
          {FEATURES.map((f, i) => (
            <motion.article
              key={f.title}
              className="feature-card"
              custom={i}
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, margin: '-40px' }}
              variants={cardVariant}
            >
              <div className={`card-icon ${f.iconColor}`}>
                <f.icon size={22} strokeWidth={2} />
              </div>
              <h3>{f.title}</h3>
              <p>{f.desc}</p>
            </motion.article>
          ))}
        </div>

        {/* Demo screenshots */}
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-40px' }}
          transition={{ duration: 0.6, delay: 0.15 }}
          className="grid-2"
          style={{ marginTop: 64 }}
        >
          <div className="demo-frame">
            <img
              src="/assets/demo-mini-mode.png"
              alt="Mini mode — compact floating widget"
              loading="lazy"
            />
          </div>
          <div className="demo-frame">
            <img
              src="/assets/demo-full-mode.png"
              alt="Full mode — expanded view with history and settings"
              loading="lazy"
            />
          </div>
        </motion.div>
      </div>
    </section>
  );
}
