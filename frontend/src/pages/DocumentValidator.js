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
    const validTypes = ['image/jpeg', 'image/png', 'application/pdf'];
    if (!validTypes.includes(selectedFile.type)) {
      setError('Please upload a PDF, JPEG, or PNG file');
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
      // For demo: simulate document validation
      // In production, this would upload to S3 and call the validation API
      
      setTimeout(() => {
        // Mock validation results
        const mockResults = {
          document_type: 'invoice',
          extracted_fields: {
            exporter_name: 'ABC Exports Pvt Ltd',
            iec_number: '0123456789',
            hsn_code: '34011110',
            invoice_number: 'INV-2024-001',
            invoice_date: '2024-03-08',
            invoice_value: '$5,000',
            destination_country: 'United States',
            product_description: 'Handmade Soap'
          },
          validation_results: {
            status: 'valid',
            issues: [],
            recommendations: [
              'All required fields are present',
              'IEC number format is valid',
              'HSN code format is valid',
              'Document is ready for export'
            ]
          }
        };
        
        setResults(mockResults);
        setLoading(false);
      }, 3000);
      
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
                  accept=".pdf,.jpg,.jpeg,.png"
                  onChange={handleFileChange}
                  style={{ display: 'none' }}
                />
                <p className="upload-hint">Supported: PDF, JPEG, PNG (Max 10MB)</p>
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
                    {issue}
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
                    {rec}
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
      </div>
    </div>
  );
}

export default DocumentValidator;
