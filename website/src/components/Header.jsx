import { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const NAV_LINKS = [
  { href: '#install', label: 'Install' },
  { href: '#privacy', label: 'Privacy' },
  { href: 'https://github.com/Vietnam-VoDich/voice-snippet', label: 'GitHub' },
];

export default function Header() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const closeMenu = useCallback(() => setMenuOpen(false), []);

  useEffect(() => {
    if (!menuOpen) return;
    const onResize = () => { if (window.innerWidth > 640) setMenuOpen(false); };
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, [menuOpen]);

  return (
    <motion.header
      initial={{ y: -30, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className={`site-header${scrolled ? ' scrolled' : ''}`}
    >
      <a href="#" className="brand" onClick={(e) => { e.preventDefault(); window.scrollTo({ top: 0, behavior: 'smooth' }); closeMenu(); }}>
        <img src="/assets/app-icon.png" alt="Voice Snippet icon" width="34" height="34" />
        <span>Voice Snippet</span>
      </a>

      {/* Hamburger button (visible on mobile) */}
      <button
        className={`hamburger${menuOpen ? ' open' : ''}`}
        onClick={() => setMenuOpen((p) => !p)}
        aria-label={menuOpen ? 'Close menu' : 'Open menu'}
        aria-expanded={menuOpen}
      >
        <span />
        <span />
        <span />
      </button>

      {/* Desktop nav */}
      <nav className="site-nav desktop-nav">
        {NAV_LINKS.map((link) => (
          <a
            key={link.label}
            href={link.href}
            {...(link.href.startsWith('http') ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
          >
            {link.label}
          </a>
        ))}
      </nav>

      {/* Mobile nav overlay */}
      <AnimatePresence>
        {menuOpen && (
          <motion.nav
            className="site-nav mobile-nav open"
            initial={{ opacity: 0, y: -12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
          >
            {NAV_LINKS.map((link, i) => (
              <motion.a
                key={link.label}
                href={link.href}
                {...(link.href.startsWith('http') ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
                onClick={closeMenu}
                initial={{ opacity: 0, x: -12 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.06, duration: 0.2 }}
              >
                {link.label}
              </motion.a>
            ))}
          </motion.nav>
        )}
      </AnimatePresence>
    </motion.header>
  );
}
