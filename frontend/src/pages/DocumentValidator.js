import React, { useState } from 'react';
import './DocumentValidator.css';

function DocumentValidator() {
  const [file, setFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState(null);
  const [error, setError] = useState(null);

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
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

    // Note: This is a placeholder. Actual implementation requires:
    // 1. API Gateway endpoint for document upload
    // 2. S3 pre-signed URL generation
    // 3. Step Functions workflow integration
    
    try {
      // Simulate API call
      setTimeout(() => {
        setResults({
          document_id: 'doc_' + Date.now(),
          status: 'Warning',
          extracted_fields: {
            exporter_name: 'ABC Exports Pvt Ltd',
            iec_number: '0123456789',
            hsn_code: '34011190',
            invoice_value: 'USD 5000',
            destination_country: 'USA',
            document_date: '2025-03-01'
          },
          errors: [
            {
              type: 'possible',
              field: 'document_date',
              message: 'Date is 7 days old. Verify if correct.',
              fix_instruction: 'Check if the invoice date matches your records.'
            }
          ]
        });
        setLoading(false);
      }, 3000);
      
      // TODO: Replace with actual API call
      // const formData = new FormData();
      // formData.append('document', file);
      // formData.append('user_id', 'web_user');
      // 
      // const response = await axios.post(`${API_URL}/api/v1/validate-document`, formData);
      // setResults(response.data);
      
    } catch (err) {
      setError('Failed to validate document. Please try again.');
      console.error('Validation error:', err);
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    if (status === 'Approved') return 'success';
    if (status === 'Warning') return 'warning';
    return 'error';
  };

  return (
    <div className="document-validator">
      <div className="card">
        <h2>Document Validator</h2>
        <p className="subtitle">Upload your commercial invoice for automated validation</p>

        <form onSubmit={handleSubmit}>
          <div className="upload-area">
            <input
              type="file"
              id="file-upload"
              accept=".pdf,.jpg,.jpeg,.png"
              onChange={handleFileChange}
              className="file-input"
            />
            <label htmlFor="file-upload" className="file-label">
              <div className="upload-icon">📄</div>
              <div className="upload-text">
                {file ? file.name : 'Click to upload or drag and drop'}
              </div>
              <div className="upload-hint">PDF, JPEG, or PNG (max 10MB)</div>
            </label>
          </div>

          <button type="submit" disabled={loading || !file} className="btn-primary">
            {loading ? 'Validating...' : 'Validate Document'}
          </button>
        </form>

        {error && (
          <div className="error-message">
            <strong>Error:</strong> {error}
          </div>
        )}

        {results && (
          <div className="results">
            <div className={`status-badge status-${getStatusColor(results.status)}`}>
              {results.status}
            </div>

            <h3>Extracted Fields</h3>
            <div className="fields-table">
              {Object.entries(results.extracted_fields).map(([key, value]) => (
                <div key={key} className="field-row">
                  <div className="field-label">{key.replace(/_/g, ' ')}</div>
                  <div className="field-value">{value || 'Not found'}</div>
                </div>
              ))}
            </div>

            {results.errors && results.errors.length > 0 && (
              <>
                <h3>Validation Issues</h3>
                {results.errors.map((error, index) => (
                  <div key={index} className={`error-card error-${error.type}`}>
                    <div className="error-header">
                      <span className="error-type">
                        {error.type === 'definite' ? '❌ Error' : '⚠️ Warning'}
                      </span>
                      <span className="error-field">{error.field}</span>
                    </div>
                    <div className="error-message-text">{error.message}</div>
                    <div className="error-fix">
                      <strong>How to fix:</strong> {error.fix_instruction}
                    </div>
                  </div>
                ))}
              </>
            )}
          </div>
        )}
      </div>

      <div className="info-card">
        <h3>What we check</h3>
        <ul className="check-list">
          <li>✓ IEC number format (10 digits)</li>
          <li>✓ HSN code format (8 digits)</li>
          <li>✓ Invoice date validity</li>
          <li>✓ Required field presence</li>
          <li>✓ Field consistency</li>
        </ul>
      </div>
    </div>
  );
}

export default DocumentValidator;
