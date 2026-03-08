import React, { useState } from 'react';
import axios from 'axios';
import './HSNClassifier.css';

// Replace with your API Gateway URL after deployment
const API_URL = process.env.REACT_APP_API_URL || 'https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod';

function HSNClassifier() {
  const [productDescription, setProductDescription] = useState('');
  const [language, setLanguage] = useState('en');
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState(null);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!productDescription.trim()) {
      setError('Please enter a product description');
      return;
    }

    setLoading(true);
    setError(null);
    setResults(null);

    try {
      const response = await axios.post(`${API_URL}/api/v1/classify-product`, {
        product_description: productDescription,
        language: language,
        user_id: 'web_user'
      });

      console.log('API Response:', response.data);
      setResults(response.data);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to classify product. Please try again.');
      console.error('Classification error:', err);
    } finally {
      setLoading(false);
    }
  };

  const getConfidenceColor = (confidence) => {
    if (confidence >= 0.8) return 'high';
    if (confidence >= 0.6) return 'medium';
    return 'low';
  };

  return (
    <div className="hsn-classifier">
      <div className="card">
        <h2>HSN Code Classifier</h2>
        <p className="subtitle">Describe your product and get HSN code suggestions</p>

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="language">Language</label>
            <select
              id="language"
              value={language}
              onChange={(e) => setLanguage(e.target.value)}
              className="select"
            >
              <option value="en">English</option>
              <option value="hi">हिंदी (Hindi)</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="description">Product Description</label>
            <textarea
              id="description"
              value={productDescription}
              onChange={(e) => setProductDescription(e.target.value)}
              placeholder={language === 'hi' ? 'अपने उत्पाद का वर्णन करें...' : 'Describe your product...'}
              rows="4"
              className="textarea"
            />
          </div>

          <button type="submit" disabled={loading} className="btn-primary">
            {loading ? 'Classifying...' : 'Classify Product'}
          </button>
        </form>

        {error && (
          <div className="error-message">
            <strong>Error:</strong> {error}
          </div>
        )}

        {results && (
          <div className="results">
            <h3>HSN Code Recommendations</h3>
            {results.model_used && (
              <p className="model-info">Powered by: {results.model_used}</p>
            )}

            {results.classifications && Array.isArray(results.classifications) && results.classifications.length > 0 ? (
              <>
                <div className="recommendation-banner">
                  <div className="recommended-badge">✓ RECOMMENDED</div>
                  <div className="recommended-code">{results.classifications[0].hsn_code}</div>
                  <div className="recommended-confidence">
                    {(results.classifications[0].confidence * 100).toFixed(0)}% Match
                  </div>
                  <p className="recommended-text">
                    Based on AI analysis, this is the most suitable HSN code for your product.
                  </p>
                </div>

                <h4>All Suggestions (Ranked by Confidence)</h4>
                {results.classifications.map((hsn, index) => (
                  <div key={index} className={`hsn-card ${index === 0 ? 'best-match' : ''}`}>
                    <div className="hsn-header">
                      <div className="hsn-rank">#{index + 1}</div>
                      <div className="hsn-code">{hsn.hsn_code}</div>
                      <div className={`confidence confidence-${getConfidenceColor(hsn.confidence)}`}>
                        {(hsn.confidence * 100).toFixed(0)}% confidence
                      </div>
                    </div>
                    
                    <div className="confidence-bar">
                      <div 
                        className={`confidence-fill confidence-${getConfidenceColor(hsn.confidence)}`}
                        style={{ width: `${hsn.confidence * 100}%` }}
                      ></div>
                    </div>
                    
                    <div className="hsn-explanation">
                      <strong>Why this code:</strong> {hsn.explanation}
                    </div>

                    {index === 0 && (
                      <div className="use-this-code">
                        <strong>✓ Use this HSN code for your export documentation</strong>
                      </div>
                    )}
                  </div>
                ))}

                <div className="disclaimer">
                  <strong>⚠️ Important:</strong> While our AI provides highly accurate suggestions, 
                  we recommend verifying the HSN code with a customs broker or the official 
                  Indian Customs tariff before finalizing your export documentation.
                </div>
              </>
            ) : (
              <div className="no-results">
                <p>No classifications found. Please try again.</p>
                <details>
                  <summary>Debug Info (click to expand)</summary>
                  <pre style={{textAlign: 'left', fontSize: '0.8rem'}}>{JSON.stringify(results, null, 2)}</pre>
                </details>
              </div>
            )}
          </div>
        )}
      </div>

      <div className="examples">
        <h3>Example Products</h3>
        <div className="example-grid">
          <button onClick={() => setProductDescription('handmade turmeric soap')} className="example-btn">
            Turmeric Soap
          </button>
          <button onClick={() => setProductDescription('cotton bedsheets')} className="example-btn">
            Cotton Bedsheets
          </button>
          <button onClick={() => setProductDescription('basmati rice')} className="example-btn">
            Basmati Rice
          </button>
          <button onClick={() => setProductDescription('wooden toys')} className="example-btn">
            Wooden Toys
          </button>
        </div>
      </div>
    </div>
  );
}

export default HSNClassifier;
