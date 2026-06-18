import { motion } from 'framer-motion';
import { Sparkles, AlignLeft, List, Mail, PenLine, FileText, MessageSquare } from 'lucide-react';

const STYLES = [
  { key: '⌘1', name: 'Clean', hint: 'Fix grammar, remove filler words', icon: Sparkles, color: 'var(--blue)' },
  { key: '⌘2', name: 'Bullets', hint: 'Turn into a bullet list', icon: List, color: 'var(--green)' },
  { key: '⌘3', name: 'Email', hint: 'Format as a professional email', icon: Mail, color: 'var(--violet)' },
  { key: '⌘4', name: 'Note', hint: 'Distill into a short note', icon: FileText, color: 'var(--cyan)' },
  { key: '⌘5', name: 'Chat', hint: 'Casual messaging tone', icon: MessageSquare, color: 'var(--amber)' },
  { key: '⌘6', name: 'Custom', hint: 'Your own rewrite style', icon: PenLine, color: 'var(--rose)' },
];

export default function StyleShowcase() {
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
          <span className="eyebrow">Rewrite Styles</span>
          <h2>Six ways to shape your words.</h2>
          <div className="section-line" />
          <p style={{ fontSize: '1.05rem', color: 'var(--muted)', maxWidth: 600, lineHeight: 1.65, marginTop: 16 }}>
            After transcription, hit a keyboard shortcut to transform rough speech into exactly the format you need. All powered by on-device Apple Foundation Models.
          </p>
        </motion.div>

        <div className="style-grid">
          {STYLES.map((s, i) => (
            <motion.div
              key={s.key}
              className="style-card"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-20px' }}
              transition={{ duration: 0.45, delay: i * 0.07, ease: [0.16, 1, 0.3, 1] }}
            >
              <span className="kbd" style={{ color: s.color, borderColor: s.color + '22' }}>{s.key}</span>
              <div>
                <div className="style-name">{s.name}</div>
                <div className="style-hint">{s.hint}</div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
