import { motion } from 'framer-motion';
import { Mic, FileText, Sparkles } from 'lucide-react';

const STEPS = [
  {
    icon: Mic,
    color: 'blue',
    title: 'Record',
    desc: 'Press a global shortcut. The floating widget appears and captures your voice.',
  },
  {
    icon: FileText,
    color: 'green',
    title: 'Transcribe',
    desc: 'WhisperKit converts speech to text locally on your Mac. Audio never leaves the device.',
  },
  {
    icon: Sparkles,
    color: 'violet',
    title: 'Format',
    desc: 'Pick a rewrite style with a keyboard shortcut. Apple Foundation Models clean up the transcript instantly.',
  },
];

const colorMap = {
  blue: { bg: 'var(--blue-light)', color: 'var(--blue)', shadow: 'var(--shadow-blue)' },
  green: { bg: 'var(--green-light)', color: 'var(--green)', shadow: 'var(--shadow-green)' },
  violet: { bg: 'var(--violet-light)', color: 'var(--violet)', shadow: 'var(--shadow-violet)' },
};

export default function HowItWorks() {
  return (
    <section className="section-padding" style={{ borderTop: '1px solid var(--line)' }}>
      <div className="dot-grid" />
      <div className="content-max" style={{ position: 'relative', zIndex: 1 }}>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.5 }}
          style={{ maxWidth: 700, marginBottom: 8 }}
        >
          <span className="eyebrow">How it works</span>
          <h2>Three steps. Zero cloud.</h2>
          <div className="section-line" />
        </motion.div>

        <div className="flow-steps" style={{ position: 'relative' }}>
          {/* Dashed connector line (hidden on mobile via CSS) */}
          <div className="flow-connector" />

          {STEPS.map((step, i) => {
            const c = colorMap[step.color];
            return (
              <motion.div
                key={step.title}
                className="flow-step"
                initial={{ opacity: 0, y: 24 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: '-30px' }}
                transition={{ duration: 0.55, delay: i * 0.15, ease: [0.16, 1, 0.3, 1] }}
              >
                <div
                  className="step-circle"
                  style={{ background: c.bg, color: c.color }}
                >
                  <step.icon size={28} strokeWidth={1.8} />
                </div>
                <div>
                  <h3 style={{ color: c.color }}>{step.title}</h3>
                  <p>{step.desc}</p>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
