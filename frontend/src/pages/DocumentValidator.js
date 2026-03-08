import React, { useState } from 'react';
import axios from 'axios';
import './DocumentValidator.css';

const API_URL = process.env.REACT_APP_API_URL || 'https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod';

function DocumentValidator() {
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState(null);
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState(null);
  const [error, setError] = useState(null);
  const [dragActive, setDragActive] = useState(false);

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      handleFile(e.target.files[0]);
    }
  };

  const handleFile = (selectedFile) => {
    // Validate file type
    const validTypes = ['image/jpeg', 'image/png', 'application/pdf', 'text/plain'];
    if (!validTypes.includes(selectedFile.type)) {
      setError('Please upload a PDF, JPEG, PNG, or TXT file');
      return;
    }
    
    // Validate file size (max 10MB)
    if (selectedFile.size > 10 * 1024 * 1024) {
      setError('File size must be less than 10MB');
      return;
    }
    
    setFile(selectedFile);
    setError(null);
    
    // Create preview for images
    if (selectedFile.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setPreview(reader.result);
      };
      reader.readAsDataURL(selectedFile);
    } else {
      setPreview(null);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!file) {
      setError('Please select a file to upload');
      return;
    }

    setLoading(true);
    setError(null);
    setResults(null);

    try {
      // Step 1: Get pre-signed URL
      const uploadResponse = await axios.post(`${API_URL}/api/v1/upload-document`, {
        file_name: file.name,
        file_type: file.type
      });

      const { upload_url, s3_key, file_id } = uploadResponse.data;

      // Step 2: Upload file to S3
      await axios.put(upload_url, file, {
        headers: {
          'Content-Type': file.type
        }
      });

      // Step 3: Trigger validation
      const validationResponse = await axios.post(`${API_URL}/api/v1/validate-document`, {
        s3_key: s3_key,
        file_id: file_id
      });

      setResults(validationResponse.data);
      setLoading(false);
      
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to validate document. Please try again.');
      console.error('Validation error:', err);
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch(status) {
      case 'valid': return 'success';
      case 'warning': return 'warning';
      case 'error': return 'error';
      default: return 'info';
    }
  };

  return (
    <div className="document-validator">
      <div className="card">
        <h2>Document Validator</h2>
        <p className="subtitle">Upload your export documents for AI-powered validation</p>

        <form onSubmit={handleSubmit}>
          <div 
            className={`upload-area ${dragActive ? 'drag-active' : ''} ${file ? 'has-file' : ''}`}
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={handleDrop}
          >
            {!file ? (
              <>
                <div className="upload-icon">📄</div>
                <p className="upload-text">Drag and drop your document here</p>
                <p className="upload-subtext">or</p>
                <label htmlFor="file-upload" className="upload-button">
                  Choose File
                </label>
                <input
                  id="file-upload"
                  type="file"
                  accept=".pdf,.jpg,.jpeg,.png,.txt"
                  onChange={handleFileChange}
                  style={{ display: 'none' }}
                />
                <p className="upload-hint">Supported: PDF, JPEG, PNG, TXT (Max 10MB)</p>
              </>
            ) : (
              <div className="file-preview">
                {preview ? (
                  <img src={preview} alt="Preview" className="preview-image" />
                ) : (
                  <div className="pdf-icon">📄</div>
                )}
                <div className="file-info">
                  <p className="file-name">{file.name}</p>
                  <p className="file-size">{(file.size / 1024).toFixed(2)} KB</p>
                  <button 
                    type="button" 
                    onClick={() => { setFile(null); setPreview(null); }}
                    className="remove-button"
                  >
                    Remove
                  </button>
                </div>
              </div>
            )}
          </div>

          {file && (
            <button type="submit" disabled={loading} className="btn-primary">
              {loading ? 'Validating...' : 'Validate Document'}
            </button>
          )}
        </form>

        {error && (
          <div className="error-message">
            <strong>Error:</strong> {error}
          </div>
        )}

        {loading && (
          <div className="loading-state">
            <div className="spinner"></div>
            <p>Analyzing document with AI...</p>
            <p className="loading-steps">
              Step 1: Extracting text with OCR ✓<br/>
              Step 2: Validating fields...<br/>
              Step 3: Generating report...
            </p>
          </div>
        )}

        {results && (
          <div className="results">
            <h3>Validation Results</h3>
            
            <div className={`status-banner status-${getStatusColor(results.validation_results.status)}`}>
              <div className="status-icon">
                {results.validation_results.status === 'valid' ? '✓' : 
                 results.validation_results.status === 'warning' ? '⚠' : '✗'}
              </div>
              <div className="status-text">
                <strong>
                  {results.validation_results.status === 'valid' ? 'Document Valid' :
                   results.validation_results.status === 'warning' ? 'Warnings Found' :
                   'Errors Found'}
                </strong>
                <p>Document Type: {results.document_type}</p>
              </div>
            </div>

            <div className="extracted-fields">
              <h4>Extracted Fields</h4>
              <table className="fields-table">
                <tbody>
                  {Object.entries(results.extracted_fields).map(([key, value]) => (
                    value && (
                      <tr key={key}>
                        <td className="field-label">{key.replace(/_/g, ' ').toUpperCase()}</td>
                        <td className="field-value">{value}</td>
                      </tr>
                    )
                  ))}
                </tbody>
              </table>
            </div>

            {results.validation_results.issues && results.validation_results.issues.length > 0 && (
              <div className="issues-section">
                <h4>Issues Found</h4>
                {results.validation_results.issues.map((issue, index) => (
                  <div key={index} className="issue-item">
                    <span className="issue-icon">⚠</span>
                    <div>
                      {typeof issue === 'string' ? (
                        issue
                      ) : (
                        <>
                          <strong>{issue.field || 'General'}:</strong> {issue.issue || issue.message || JSON.stringify(issue)}
                          {issue.description && <p style={{marginTop: '5px', fontSize: '0.9em', color: '#666'}}>{issue.description}</p>}
                        </>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {results.validation_results.recommendations && results.validation_results.recommendations.length > 0 && (
              <div className="recommendations-section">
                <h4>Recommendations</h4>
                {results.validation_results.recommendations.map((rec, index) => (
                  <div key={index} className="recommendation-item">
                    <span className="rec-icon">💡</span>
                    <div>
                      {typeof rec === 'string' ? rec : JSON.stringify(rec)}
                    </div>
                  </div>
                ))}
              </div>
            )}

            <button className="btn-secondary" onClick={() => window.print()}>
              Download Report
            </button>
          </div>
        )}
      </div>

      <div className="info-section">
        <h3>What We Validate</h3>
        <div className="info-grid">
          <div className="info-card">
            <div className="info-icon">📋</div>
            <h4>Required Fields</h4>
            <p>IEC number, HSN code, invoice details, destination</p>
          </div>
          <div className="info-card">
            <div className="info-icon">✓</div>
            <h4>Format Validation</h4>
            <p>Check correct formats for IEC, HSN, dates, values</p>
          </div>
          <div className="info-card">
            <div className="info-icon">🔍</div>
            <h4>Consistency Checks</h4>
            <p>Verify data consistency across all fields</p>
          </div>
          <div className="info-card">
            <div className="info-icon">⚡</div>
            <h4>Fast Processing</h4>
            <p>Results in under 15 seconds</p>
          </div>
        </div>
        
        <div className="info-note" style={{
          marginTop: '20px',
          padding: '15px',
          backgroundColor: '#fff3cd',
          borderLeft: '4px solid #ffc107',
          borderRadius: '4px'
        }}>
          <strong>💡 Testing Tip:</strong> Use text files (.txt) for testing! 
          Amazon Textract (for PDF/image processing) requires a subscription. 
          Text files work perfectly and demonstrate all validation features.
          <br/>
          <small>Sample files available in the test-data folder.</small>
        </div>
      </div>
    </div>
  );
}

export default DocumentValidator;
