# Design Document: NiryatSaathi

## Overview

NiryatSaathi is a full-stack AI-powered export compliance assistant designed specifically for Indian MSME exporters. The system provides a WhatsApp-first, multilingual interface that guides users through product classification (HSN codes), document validation, government scheme eligibility, RCMC routing, and compliance alerts.

The architecture follows a microservices-inspired approach with clear separation between the API layer, AI processing layer, data layer, and external integrations. The system prioritizes mobile-first design, data efficiency, offline capability, and multilingual support to serve users in tier 2/3 Indian cities with varying levels of connectivity and technical literacy.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │   React Web App  │  │  WhatsApp Client │                │
│  │   (PWA + PWA)    │  │                  │                │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway Layer                       │
│                    FastAPI Application                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Authentication │ Rate Limiting │ Request Routing    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│   HSN        │  │   Document       │  │   Scheme     │
│ Classifier   │  │   Checker        │  │   Advisor    │
│   Service    │  │   Service        │  │   Service    │
└──────────────┘  └──────────────────┘  └──────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      AI Processing Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Claude     │  │   Whisper    │  │  IndicTrans2 │     │
│  │     API      │  │     API      │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         RAG Pipeline (LangChain + FAISS)             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  PostgreSQL  │  │    Redis     │  │    FAISS     │     │
│  │   Database   │  │    Cache     │  │ Vector Store │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Background Processing                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Celery Workers (Document OCR, Data Scraping, Alerts)│  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Backend:**
- FastAPI (Python) - API framework
- PostgreSQL - Primary database for user data, HSN codes, document history
- Redis - Caching layer for government scheme data and session management
- Celery - Background task processing for document OCR and data scraping

**AI/ML Layer:**
- Claude API (claude-sonnet) - Conversational AI and HSN classification
- Whisper API - Hindi voice-to-text transcription
- IndicTrans2 - Regional language translation (open source, IIT Madras)
- LangChain + FAISS - RAG pipeline for government policy documents

**Frontend:**
- React - Web application framework
- Progressive Web App (PWA) - Offline capability
- WhatsApp Business API - Primary user interface

**External Integrations:**
- CBIC HSN code master list (CSV import)
- DGFT trade notices (web scraping)
- Ministry of Commerce APIs (structured JSON)
- ICEGATE public duty calculator (API wrapper)

## Components and Interfaces

### 1. API Gateway Layer

**FastAPIApplication**
- Handles all HTTP requests from web and WhatsApp clients
- Implements authentication using JWT tokens
- Rate limiting: 100 requests per minute per user
- Request routing to appropriate service handlers

**Endpoints:**
```
POST /api/v1/hsn/classify
POST /api/v1/documents/validate
POST /api/v1/schemes/recommend
POST /api/v1/rcmc/route
GET  /api/v1/alerts
POST /api/v1/voice/transcribe
POST /api/v1/translate
```

### 2. HSN Classifier Service

**HSNClassifier**

Purpose: Classifies user product descriptions into 8-digit HSN codes

Methods:
- `classify_product(description: str, language: str) -> List[HSNMatch]`
  - Takes product description and language code
  - Returns top 3 HSN matches with confidence scores
  - Each HSNMatch contains: code, description, confidence_score, explanation, has_restrictions

- `get_restrictions(hsn_code: str) -> List[Restriction]`
  - Returns export restrictions for a given HSN code
  - Includes license requirements and prohibited destinations

**Implementation Approach:**
1. Translate user input to English if needed (using IndicTrans2)
2. Use Claude API with RAG context from HSN code database
3. Prompt engineering: "Given this product description, identify the most appropriate 8-digit HSN codes. Consider the material, purpose, and manufacturing process."
4. Parse Claude response into structured HSNMatch objects
5. Query PostgreSQL for restriction data
6. Translate explanations back to user's language

**Data Model:**
```python
class HSNMatch:
    code: str  # 8-digit HSN code
    description: str
    confidence_score: float  # 0.0 to 1.0
    explanation: str  # Plain language reasoning
    has_restrictions: bool
    restrictions: List[Restriction]

class Restriction:
    type: str  # "license_required", "prohibited_destination", "special_permit"
    description: str
    applicable_countries: List[str]
```

### 3. Document Checker Service

**DocumentValidator**

Purpose: Validates export documents for consistency and completeness

Methods:
- `validate_document(file: UploadFile, doc_type: str) -> ValidationResult`
  - Accepts document image/PDF and document type
  - Returns validation result with extracted fields and errors

- `cross_check_documents(documents: List[Document]) -> List[ConsistencyError]`
  - Checks consistency across multiple documents
  - Returns list of inconsistencies found

**Implementation Approach:**
1. Queue document for background processing using Celery
2. Celery worker performs OCR using Tesseract (supports Hindi/English)
3. Extract key fields using regex patterns and field position templates
4. Store extracted data in PostgreSQL
5. Run consistency checks:
   - Name matching across documents (fuzzy matching with 90% threshold)
   - IEC number consistency
   - HS code consistency
   - Invoice value matching between invoice and packing list
   - Date validation (shipping date after invoice date)
6. Classify errors as "definite" (e.g., mismatched IEC) or "possible" (e.g., slight name variation)
7. Generate plain-language fix instructions

**Data Model:**
```python
class Document:
    id: str
    user_id: str
    doc_type: str  # "commercial_invoice", "packing_list", etc.
    upload_date: datetime
    extracted_fields: Dict[str, Any]
    ocr_confidence: float

class ValidationResult:
    document_id: str
    extracted_fields: Dict[str, Any]
    errors: List[ValidationError]
    warnings: List[ValidationWarning]
    processing_time: float

class ValidationError:
    field: str
    error_type: str  # "missing", "invalid_format", "inconsistent"
    severity: str  # "definite", "possible"
    message: str  # Plain language explanation
    fix_instruction: str
```

**Supported Document Types and Fields:**

| Document Type | Key Fields |
|--------------|------------|
| Commercial Invoice | exporter_name, iec_number, invoice_number, invoice_date, hs_code, invoice_value, destination_country, buyer_name |
| Packing List | exporter_name, invoice_number, total_packages, gross_weight, net_weight |
| Bill of Lading | shipper_name, consignee_name, vessel_name, port_of_loading, port_of_discharge, bl_number, bl_date |
| Certificate of Origin | exporter_name, hs_code, country_of_origin, destination_country, certificate_number |
| Shipping Bill | iec_number, sb_number, sb_date, port_code, hs_code, fob_value |

### 4. Scheme Advisor Service

**SchemeAdvisor**

Purpose: Recommends applicable government export schemes

Methods:
- `recommend_schemes(criteria: EligibilityCriteria) -> List[SchemeRecommendation]`
  - Takes user business criteria
  - Returns list of applicable schemes with benefit estimates

- `get_application_guide(scheme_name: str) -> ApplicationGuide`
  - Returns step-by-step application instructions for a scheme

**Implementation Approach:**
1. Load scheme eligibility rules from structured JSON (stored in Redis)
2. Apply rule-based filtering:
   - RoDTEP: All exporters with valid IEC
   - Duty Drawback: Exporters who paid customs duties on inputs
   - Advance Authorization: Exporters with regular export track record
   - EPCG: Capital goods importers with export obligation
   - SEIS: Service exporters only
3. Calculate estimated benefits using formulas:
   - RoDTEP: FOB value × product-specific rate (from DGFT schedule)
   - Duty Drawback: Input duty paid × drawback rate
4. Use Claude API with RAG context to generate step-by-step guides
5. Translate to user's preferred language

**Data Model:**
```python
class EligibilityCriteria:
    product_type: str
    hs_code: str
    destination_country: str
    business_size: str  # "micro", "small", "medium"
    iec_status: bool
    annual_turnover: float
    has_export_history: bool

class SchemeRecommendation:
    scheme_name: str
    estimated_benefit: float  # in INR
    eligibility_match: float  # 0.0 to 1.0
    application_complexity: str  # "simple", "moderate", "complex"
    processing_time: str  # "2-4 weeks"
    dgft_portal_link: str

class ApplicationGuide:
    scheme_name: str
    steps: List[str]
    required_documents: List[str]
    estimated_time: str
    fees: float
```

### 5. RCMC Router Service

**RCMCRouter**

Purpose: Maps products to appropriate Export Promotion Councils

Methods:
- `route_to_epc(product_info: ProductInfo) -> EPCRecommendation`
  - Takes product/sector information
  - Returns recommended EPC with application details

**Implementation Approach:**
1. Maintain mapping table of HSN code ranges to EPCs (26 EPCs total)
2. Use rule-based matching:
   - Textiles → TEXPROCIL
   - Handicrafts → EPCH
   - Engineering goods → EEPC India
   - Chemicals → CHEMEXCIL
   - etc.
3. Query PostgreSQL for EPC-specific requirements
4. Return checklist, fees, and processing time

**Data Model:**
```python
class ProductInfo:
    product_description: str
    hsn_code: str
    sector: str

class EPCRecommendation:
    epc_name: str
    epc_code: str
    website: str
    application_checklist: List[str]
    required_documents: List[str]
    processing_time: str
    fees: float
    contact_info: ContactInfo
```

### 6. Alert Manager Service

**AlertManager**

Purpose: Sends compliance reminders and regulatory updates

Methods:
- `schedule_iec_reminder(user_id: str, iec_issue_date: date)`
  - Schedules annual IEC update reminder (April-June window)

- `schedule_rcmc_reminder(user_id: str, rcmc_expiry_date: date)`
  - Schedules RCMC renewal reminder (30 days before expiry)

- `notify_rule_change(destination_country: str, change_description: str)`
  - Notifies all affected users of import rule changes

- `notify_new_scheme(scheme_details: SchemeDetails)`
  - Notifies eligible users of new export schemes

**Implementation Approach:**
1. Use Celery Beat for scheduled tasks
2. Store user preferences in PostgreSQL (notification channels, frequency)
3. Send notifications via:
   - WhatsApp Business API (primary)
   - Email (secondary)
   - Web app push notifications (tertiary)
4. Track notification delivery status
5. Implement retry logic for failed deliveries

**Data Model:**
```python
class Alert:
    id: str
    user_id: str
    alert_type: str  # "iec_renewal", "rcmc_renewal", "rule_change", "new_scheme"
    title: str
    message: str
    scheduled_date: datetime
    sent_date: Optional[datetime]
    delivery_status: str  # "pending", "sent", "failed"
    channels: List[str]  # ["whatsapp", "email"]
```

### 7. Translation Service

**TranslationService**

Purpose: Handles multilingual support across the application

Methods:
- `translate(text: str, source_lang: str, target_lang: str) -> str`
  - Translates text between supported languages

- `detect_language(text: str) -> str`
  - Detects language of input text

**Implementation Approach:**
1. Primary languages (Hindi, English): Direct support
2. Secondary languages (Marathi, Gujarati, Punjabi, Tamil): Use IndicTrans2
3. Cache common translations in Redis
4. Fallback to English if translation fails

**Supported Languages:**
- hi: Hindi
- en: English
- mr: Marathi
- gu: Gujarati
- pa: Punjabi
- ta: Tamil

### 8. Voice Transcription Service

**VoiceTranscriptionService**

Purpose: Converts voice input to text

Methods:
- `transcribe(audio_file: UploadFile, language: str) -> str`
  - Transcribes audio to text in specified language

**Implementation Approach:**
1. Accept audio in common formats (MP3, WAV, OGG)
2. Use Whisper API for transcription
3. Specify language hint for better accuracy
4. Return transcribed text for further processing

### 9. WhatsApp Integration Service

**WhatsAppService**

Purpose: Handles WhatsApp Business API integration

Methods:
- `send_message(phone_number: str, message: str, language: str)`
  - Sends text message to user

- `send_document(phone_number: str, document: bytes, filename: str)`
  - Sends document to user

- `handle_incoming_message(webhook_data: dict) -> Response`
  - Processes incoming WhatsApp messages

**Implementation Approach:**
1. Use WhatsApp Business API webhooks
2. Parse incoming messages (text, voice, document)
3. Route to appropriate service based on message content
4. Maintain conversation context in Redis (session management)
5. Implement conversational flow:
   - Greeting and language selection
   - Feature menu
   - Context-aware responses
6. Handle rate limits (1000 messages per day per number)

## Data Models

### User Model

```python
class User:
    id: str  # UUID
    phone_number: str  # Primary identifier
    name: str
    business_name: str
    iec_number: Optional[str]
    iec_issue_date: Optional[date]
    rcmc_number: Optional[str]
    rcmc_expiry_date: Optional[date]
    preferred_language: str  # "hi", "en", etc.
    business_size: str  # "micro", "small", "medium"
    primary_products: List[str]
    created_at: datetime
    last_active: datetime
    notification_preferences: NotificationPreferences
```

### HSN Code Model

```python
class HSNCode:
    code: str  # 8-digit code (primary key)
    description_en: str
    description_hi: str
    chapter: str  # First 2 digits
    heading: str  # First 4 digits
    has_restrictions: bool
    restrictions: List[Restriction]
    applicable_schemes: List[str]
    rodtep_rate: Optional[float]
    duty_drawback_rate: Optional[float]
```

### Document History Model

```python
class DocumentHistory:
    id: str
    user_id: str
    document_type: str
    upload_date: datetime
    file_path: str  # S3 or local storage path
    extracted_data: Dict[str, Any]  # JSON field
    validation_result: Dict[str, Any]  # JSON field
    consent_given: bool
    deletion_date: Optional[datetime]  # 30 days after upload if no consent
```

### Scheme Data Model

```python
class ExportScheme:
    scheme_code: str
    scheme_name: str
    description: str
    eligibility_rules: Dict[str, Any]  # JSON field
    benefit_calculation: str  # Formula or fixed amount
    application_process: List[str]
    required_documents: List[str]
    processing_time: str
    dgft_link: str
    last_updated: datetime
```

### EPC Mapping Model

```python
class EPCMapping:
    epc_code: str
    epc_name: str
    hsn_code_ranges: List[str]  # e.g., ["5201-5212", "6001-6006"]
    sectors: List[str]
    website: str
    contact_email: str
    contact_phone: str
    rcmc_fees: float
    processing_time: str
    required_documents: List[str]
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, I identified the following redundancies and consolidations:

**Consolidated Properties:**
- Requirements 1.1 and 1.2 can be combined: verifying 3 results with confidence scores AND explanations in one property
- Requirements 2.2 and 2.1 overlap: field extraction verification covers both
- Requirements 3.3, 3.4, and 3.5 can be combined: all scheme recommendations must have complete information
- Requirements 4.3 and 4.4 can be combined: EPC recommendations must have complete information
- Requirements 9.1 and 9.2 are related but test different aspects: keep separate

**Properties to Keep Separate:**
- HSN classification warning properties (1.3, 1.4) test different conditions
- Document validation properties (2.3, 2.4, 2.5) test different aspects of validation
- Alert properties (5.3, 5.4) test different event types
- Offline properties (8.3, 8.4) test different scenarios

### HSN Classification Properties

**Property 1: Complete HSN classification results**

*For any* product description in Hindi or English, the HSN classifier should return exactly 3 HSN matches, where each match contains an 8-digit code, a confidence score between 0.0 and 1.0, and a non-empty plain language explanation.

**Validates: Requirements 1.1, 1.2**

**Property 2: Restriction warnings for restricted HSN codes**

*For any* HSN code that has export restrictions in the database, when that code appears in classification results, the result should include a warning message about special licenses or restrictions.

**Validates: Requirements 1.3**

**Property 3: Low confidence broker verification warning**

*For any* classification result where the highest confidence score is below 0.8, the system should include a warning message advising the user to verify with a customs broker.

**Validates: Requirements 1.4**

### Document Validation Properties

**Property 4: Document field extraction completeness**

*For any* uploaded document (image or PDF), the OCR extraction result should contain all expected field keys for that document type (exporter_name, iec_number, hs_code, invoice_value, destination_country, date), even if some values are null.

**Validates: Requirements 2.1, 2.2**

**Property 5: Cross-document consistency detection**

*For any* set of documents with known inconsistencies (e.g., mismatched IEC numbers, different exporter names, invoice value discrepancies), the cross-check function should detect and return all inconsistencies.

**Validates: Requirements 2.3**

**Property 6: Validation error completeness**

*For any* detected validation error, the error object should contain both a plain-language error message and a fix instruction.

**Validates: Requirements 2.4**

**Property 7: Error severity classification**

*For any* validation result containing errors, all errors should have a severity field with value either "definite" or "possible".

**Validates: Requirements 2.5**

**Property 8: Document retention without consent**

*For any* document uploaded without user consent, the document record should have a deletion_date set to exactly 30 days after the upload_date.

**Validates: Requirements 2.8**

### Government Scheme Properties

**Property 9: Scheme recommendation completeness**

*For any* eligibility criteria provided by a user, each recommended scheme should include a non-null estimated benefit amount, a non-empty application guide with at least one step, and a valid DGFT portal URL.

**Validates: Requirements 3.1, 3.3, 3.4, 3.5**

### RCMC Routing Properties

**Property 10: EPC recommendation completeness**

*For any* product information that maps to an EPC, the EPC recommendation should include a non-empty application checklist, a processing time string, and a fees value greater than or equal to zero.

**Validates: Requirements 4.1, 4.3, 4.4**

### Compliance Alert Properties

**Property 11: Rule change notifications**

*For any* destination country import rule change event, all users who have exported to that country (based on document history) should receive a notification in their alert queue.

**Validates: Requirements 5.3**

**Property 12: New scheme notifications**

*For any* new export scheme announcement, all users who meet the basic eligibility criteria for that scheme should receive a notification in their alert queue.

**Validates: Requirements 5.4**

### Multilingual Support Properties

**Property 13: Response language consistency**

*For any* API request with a specified preferred language, all text fields in the response (explanations, error messages, instructions) should be in the requested language.

**Validates: Requirements 6.3**

### WhatsApp Integration Properties

**Property 14: WhatsApp document processing**

*For any* document uploaded via WhatsApp, the system should process it through the document validation pipeline and return a validation result with the same structure as web uploads.

**Validates: Requirements 7.3**

### Offline Capability Properties

**Property 15: Offline HSN lookup from cache**

*For any* HSN code in the cached top 500 codes, when the user is offline, the lookup should return the HSN code details without requiring network access.

**Validates: Requirements 8.3**

**Property 16: Offline uncached data error**

*For any* request for data not in the offline cache, when the user is offline, the system should return an error message indicating that internet connectivity is required.

**Validates: Requirements 8.4**

### Data Efficiency Properties

**Property 17: Response size limit**

*For any* API response, the total payload size (after compression) should be less than or equal to 100KB.

**Validates: Requirements 9.1**

**Property 18: Response compression**

*For any* API response larger than 1KB, the response should include compression headers (Content-Encoding: gzip or br) and the content should be compressed.

**Validates: Requirements 9.2**

### Data Privacy Properties

**Property 19: Consent-based document retention**

*For any* document uploaded with user consent, the document record should not have an automatic deletion_date set, allowing indefinite retention per consent terms.

**Validates: Requirements 10.3**

### Image Optimization Property

**Property 20: Camera upload image preprocessing**

*For any* document image uploaded via camera capture, the image should be preprocessed (resized to max 2000px width, contrast enhanced) before being sent to the OCR engine.

**Validates: Requirements 12.5**

## Error Handling

### Error Categories

The system implements comprehensive error handling across four categories:

**1. User Input Errors**
- Invalid product descriptions (empty, too short)
- Unsupported file formats for documents
- Missing required fields in API requests
- Invalid language codes

**Response Strategy:**
- Return 400 Bad Request with plain-language error message
- Provide specific guidance on how to fix the input
- Translate error messages to user's preferred language

**2. External Service Errors**
- Claude API failures or timeouts
- Whisper API failures
- IndicTrans2 translation failures
- WhatsApp API rate limits or downtime

**Response Strategy:**
- Implement retry logic with exponential backoff (3 retries)
- Fallback to cached responses where possible
- Return 503 Service Unavailable with user-friendly message
- Log errors for monitoring and alerting

**3. Data Processing Errors**
- OCR extraction failures (poor image quality)
- Document parsing errors
- Inconsistent data in cross-checks
- Missing reference data (HSN codes, EPC mappings)

**Response Strategy:**
- Return partial results with warnings when possible
- Provide confidence scores for uncertain extractions
- Suggest manual verification for low-confidence results
- Log errors for data quality improvement

**4. System Errors**
- Database connection failures
- Redis cache unavailability
- Celery worker failures
- File storage errors

**Response Strategy:**
- Implement circuit breaker pattern for external dependencies
- Graceful degradation (e.g., skip caching if Redis is down)
- Return 500 Internal Server Error with generic message to user
- Alert operations team for immediate investigation
- Maintain error logs with full stack traces

### Error Response Format

All API errors follow a consistent JSON structure:

```json
{
  "error": {
    "code": "INVALID_DOCUMENT_FORMAT",
    "message": "The uploaded file format is not supported. Please upload a PDF, JPG, or PNG file.",
    "message_localized": "अपलोड की गई फ़ाइल प्रारूप समर्थित नहीं है। कृपया PDF, JPG, या PNG फ़ाइल अपलोड करें।",
    "details": {
      "supported_formats": ["pdf", "jpg", "jpeg", "png"],
      "received_format": "docx"
    },
    "request_id": "req_abc123xyz"
  }
}
```

### Timeout Handling

- API Gateway timeout: 30 seconds
- HSN classification timeout: 5 seconds (with retry)
- Document OCR timeout: 45 seconds (background job)
- Translation timeout: 3 seconds (with fallback to English)
- WhatsApp webhook response: 10 seconds (acknowledge immediately, process async)

### Rate Limiting

- Per user: 100 requests per minute
- Per IP: 500 requests per minute
- WhatsApp: 1000 messages per day per phone number
- Claude API: 50 requests per minute (shared across all users)

**Rate Limit Response:**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "You have exceeded the request limit. Please try again in 60 seconds.",
    "retry_after": 60
  }
}
```

## Testing Strategy

### Dual Testing Approach

The system requires both unit testing and property-based testing for comprehensive coverage:

**Unit Tests:**
- Specific examples demonstrating correct behavior
- Edge cases (empty inputs, boundary values, special characters)
- Error conditions (invalid formats, missing data, API failures)
- Integration points between components
- Mock external services (Claude API, Whisper API, WhatsApp API)

**Property-Based Tests:**
- Universal properties that hold for all inputs
- Comprehensive input coverage through randomization
- Minimum 100 iterations per property test
- Each test tagged with: **Feature: niryat-saathi, Property {number}: {property_text}**

### Testing Framework Selection

**Backend (Python):**
- pytest - Unit testing framework
- Hypothesis - Property-based testing library
- pytest-asyncio - Async test support
- pytest-mock - Mocking external services
- faker - Generate realistic test data (Indian names, phone numbers, addresses)

**Frontend (React):**
- Jest - Unit testing framework
- React Testing Library - Component testing
- fast-check - Property-based testing for JavaScript
- MSW (Mock Service Worker) - API mocking

### Property Test Configuration

Each property test must:
1. Run minimum 100 iterations (configured in Hypothesis settings)
2. Include a comment tag referencing the design property
3. Use appropriate generators for Indian context (Hindi text, phone numbers with +91, IEC format)
4. Test the property across the full input space

**Example Property Test Structure:**

```python
from hypothesis import given, settings
from hypothesis import strategies as st

# Feature: niryat-saathi, Property 1: Complete HSN classification results
@settings(max_examples=100)
@given(
    description=st.text(min_size=10, max_size=500),
    language=st.sampled_from(['hi', 'en'])
)
def test_hsn_classification_completeness(description, language):
    """
    For any product description in Hindi or English, the HSN classifier 
    should return exactly 3 HSN matches with codes, confidence scores, 
    and explanations.
    """
    result = hsn_classifier.classify_product(description, language)
    
    assert len(result) == 3
    for match in result:
        assert len(match.code) == 8
        assert 0.0 <= match.confidence_score <= 1.0
        assert len(match.explanation) > 0
```

### Test Data Strategy

**Synthetic Data Generation:**
- Use Faker with Indian locale for realistic names, addresses, phone numbers
- Generate valid IEC numbers (10-digit format)
- Generate valid HSN codes from actual CBIC master list
- Create realistic product descriptions in Hindi and English

**Test Fixtures:**
- Sample export documents (invoices, packing lists, bills of lading)
- Known HSN code mappings for common products
- EPC mapping data for all 26 councils
- Government scheme eligibility rules

**Edge Cases to Test:**
- Empty or whitespace-only inputs
- Very long product descriptions (>1000 characters)
- Special characters and emojis in Hindi text
- Malformed document images (rotated, low resolution, poor lighting)
- Documents with mixed Hindi-English text
- Boundary values (exactly 100KB response, exactly 0.8 confidence)

### Integration Testing

**API Integration Tests:**
- End-to-end flows: product description → HSN classification → scheme recommendation
- Document upload → OCR → validation → error reporting
- WhatsApp message → processing → response delivery
- Multi-document consistency checking

**External Service Integration:**
- Mock Claude API responses for consistent testing
- Mock Whisper API for voice transcription
- Test fallback behavior when external services fail
- Test retry logic and circuit breakers

### Performance Testing

While not part of unit/property tests, the following performance tests should be conducted separately:

- Load testing: 1000 concurrent users
- HSN classification response time: <3 seconds (95th percentile)
- Document processing time: <30 seconds (95th percentile)
- API response time: <500ms for cached data
- Database query performance: <100ms for HSN lookups

### Test Coverage Goals

- Unit test coverage: >80% of code
- Property test coverage: 100% of correctness properties
- Integration test coverage: All critical user flows
- Edge case coverage: All identified edge cases from requirements

### Continuous Testing

- Run unit tests on every commit (CI pipeline)
- Run property tests on every pull request
- Run integration tests before deployment
- Monitor test execution time (fail if >5 minutes)
- Track flaky tests and fix or remove them
