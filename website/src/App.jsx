import Header from './components/Header'
import Hero from './components/Hero'
import HowItWorks from './components/HowItWorks'
import Features from './components/Features'
import StyleShowcase from './components/StyleShowcase'
import Footer from './components/Footer'

function App() {
  return (
    <div className="app-container">
      <Header />
      <main>
        <Hero />
        <HowItWorks />
        <Features />
        <StyleShowcase />
      </main>
      <Footer />
    </div>
  )
}

export default App
