import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import './App.css';
import HSNClassifier from './pages/HSNClassifier';
import DocumentValidator from './pages/DocumentValidator';

function App() {
  return (
    <Router>
      <div className="App">
        <header className="header">
          <div className="container">
            <h1 className="logo">🚢 NiryatSaathi</h1>
            <p className="tagline">AI-Powered Export Compliance Assistant</p>
          </div>
        </header>

        <nav className="nav">
          <div className="container">
            <Link to="/" className="nav-link">HSN Classifier</Link>
            <Link to="/document-validator" className="nav-link">Document Validator</Link>
          </div>
        </nav>

        <main className="main">
          <div className="container">
            <Routes>
              <Route path="/" element={<HSNClassifier />} />
              <Route path="/document-validator" element={<DocumentValidator />} />
            </Routes>
          </div>
        </main>

        <footer className="footer">
          <div className="container">
            <p className="disclaimer">
              ⚠️ This is AI-assisted decision support, not legal advice. 
              Always verify with customs brokers for critical export decisions.
            </p>
            <p className="copyright">© 2025 NiryatSaathi. Built for Indian MSME Exporters.</p>
          </div>
        </footer>
      </div>
    </Router>
  );
}

export default App;
