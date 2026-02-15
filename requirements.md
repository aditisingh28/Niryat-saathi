# Requirements Document: NiryatSaathi

## Introduction

NiryatSaathi is a WhatsApp-first, multilingual AI-powered export compliance assistant designed for Indian MSME exporters. The system guides small business owners through the complete export compliance journey, from product classification to document verification to government scheme eligibility, in Hindi and English (with support for additional regional languages).

The target user is a small business owner in tier 2/3 Indian cities who exports handmade goods, textiles, food products, or handicrafts. They have basic smartphone literacy but limited knowledge of trade terminology, HS codes, or government portals.

## Glossary

- **System**: The NiryatSaathi application
- **HSN_Classifier**: The component that classifies products into HSN codes
- **Document_Checker**: The component that validates export documents
- **Scheme_Advisor**: The component that recommends government schemes
- **RCMC_Router**: The component that maps products to Export Promotion Councils
- **Alert_Manager**: The component that sends compliance reminders
- **User**: An Indian MSME exporter using the system
- **HSN_Code**: Harmonized System of Nomenclature code (8-digit classification)
- **IEC**: Import Export Code (mandatory for Indian exporters)
- **RCMC**: Registration cum Membership Certificate (issued by Export Promotion Councils)
- **EPC**: Export Promotion Council
- **DGFT**: Directorate General of Foreign Trade
- **RoDTEP**: Remission of Duties and Taxes on Exported Products
- **EPCG**: Export Promotion Capital Goods scheme
- **SEIS**: Service Exports from India Scheme
- **OCR**: Optical Character Recognition
- **RAG**: Retrieval Augmented Generation

## Requirements

### Requirement 1: HSN Code Classification

**User Story:** As an exporter, I want to describe my product in plain language and receive accurate HSN code suggestions, so that I can correctly classify my goods for export.

#### Acceptance Criteria

1. WHEN a User provides a product description in Hindi or English, THE HSN_Classifier SHALL return the top 3 matching 8-digit HSN codes with confidence scores
2. WHEN the HSN_Classifier returns results, THE System SHALL provide a plain language explanation for each suggested code
3. WHEN a suggested HSN code has export restrictions, THE System SHALL display a warning message indicating special licenses may be required
4. WHEN the highest confidence score is below 80%, THE System SHALL display a warning to verify with a customs broker
5. WHEN a User provides voice input, THE System SHALL transcribe Hindi speech to text using speech recognition
6. THE System SHALL process HSN classification requests within 3 seconds

### Requirement 2: Document Validation

**User Story:** As an exporter, I want to upload my export documents and receive automated error checking, so that I can fix mistakes before submission to customs.

#### Acceptance Criteria

1. WHEN a User uploads a document image or PDF, THE Document_Checker SHALL extract key fields using OCR
2. THE Document_Checker SHALL extract the following fields: exporter name, IEC number, HS code, invoice value, destination country, and date
3. WHEN all fields are extracted, THE Document_Checker SHALL cross-check fields for consistency across documents
4. WHEN inconsistencies are detected, THE System SHALL return a checklist of errors with plain-language fix instructions
5. THE System SHALL distinguish between definite errors and possible issues in validation results
6. THE System SHALL support the following document types: Commercial Invoice, Packing List, Bill of Lading, Certificate of Origin, and Shipping Bill
7. THE System SHALL process document validation within 30 seconds
8. WHEN a User does not provide consent, THE System SHALL delete document data after 30 days

### Requirement 3: Government Scheme Recommendations

**User Story:** As an exporter, I want to know which government schemes I'm eligible for, so that I can maximize my export benefits and subsidies.

#### Acceptance Criteria

1. WHEN a User provides product type, destination country, business size, and IEC status, THE Scheme_Advisor SHALL return a list of applicable government schemes
2. THE Scheme_Advisor SHALL evaluate eligibility for the following schemes: RoDTEP, Duty Drawback, Advance Authorization, EPCG, and SEIS
3. WHEN schemes are recommended, THE System SHALL provide an estimated benefit amount for each scheme
4. WHEN schemes are recommended, THE System SHALL provide a step-by-step application guide for each scheme
5. WHEN schemes are recommended, THE System SHALL include links to relevant DGFT portal pages

### Requirement 4: RCMC Routing

**User Story:** As an exporter, I want to know which Export Promotion Council I should register with, so that I can obtain my RCMC certificate.

#### Acceptance Criteria

1. WHEN a User provides their product or sector information, THE RCMC_Router SHALL map them to the correct Export Promotion Council
2. THE RCMC_Router SHALL select from 26 available Export Promotion Councils
3. WHEN an EPC is identified, THE System SHALL provide an RCMC application checklist specific to that EPC
4. WHEN an EPC is identified, THE System SHALL display estimated processing time and fees

### Requirement 5: Compliance Alerts

**User Story:** As an exporter, I want to receive timely reminders about compliance deadlines, so that I don't miss important renewal dates or regulatory changes.

#### Acceptance Criteria

1. WHEN the annual IEC update window approaches (April-June), THE Alert_Manager SHALL send a reminder to the User
2. WHEN an RCMC renewal date approaches, THE Alert_Manager SHALL send a reminder to the User
3. WHEN destination country import rules change, THE Alert_Manager SHALL notify the User
4. WHEN new government export schemes are announced, THE Alert_Manager SHALL notify the User

### Requirement 6: Multilingual Support

**User Story:** As an exporter who is more comfortable in my regional language, I want to interact with the system in Hindi or other Indian languages, so that I can understand export compliance requirements clearly.

#### Acceptance Criteria

1. THE System SHALL support Hindi and English as primary languages
2. THE System SHALL support Marathi, Gujarati, Punjabi, and Tamil as secondary languages
3. WHEN a User selects a preferred language, THE System SHALL provide all responses in that language
4. WHEN a User provides voice input in Hindi, THE System SHALL transcribe it accurately using speech recognition

### Requirement 7: WhatsApp Integration

**User Story:** As an exporter with basic smartphone literacy, I want to access the system through WhatsApp, so that I can use a familiar interface without installing new apps.

#### Acceptance Criteria

1. THE System SHALL integrate with WhatsApp Business API for conversational interactions
2. WHEN a User sends a message via WhatsApp, THE System SHALL respond within 3 seconds
3. WHEN a User uploads a document via WhatsApp, THE System SHALL process it and return validation results
4. THE System SHALL support voice messages through WhatsApp

### Requirement 8: Offline Capability

**User Story:** As an exporter in an area with unreliable internet, I want to access basic HSN lookup functionality offline, so that I can continue working without connectivity.

#### Acceptance Criteria

1. THE System SHALL implement Progressive Web App (PWA) functionality with service worker caching
2. THE System SHALL cache the top 500 HSN codes for offline access
3. WHEN a User is offline, THE System SHALL provide HSN lookup from cached data
4. WHEN a User is offline and requests uncached data, THE System SHALL inform them that internet connectivity is required

### Requirement 9: Data Efficiency

**User Story:** As an exporter using mobile data, I want the system to consume minimal data, so that I can afford to use it regularly.

#### Acceptance Criteria

1. THE System SHALL limit data transfer to under 100KB per interaction
2. WHEN transmitting responses, THE System SHALL compress data appropriately
3. WHEN loading resources, THE System SHALL prioritize essential content over optional elements

### Requirement 10: Data Privacy and Compliance

**User Story:** As an exporter, I want my business documents to be handled securely and privately, so that my confidential information is protected.

#### Acceptance Criteria

1. THE System SHALL comply with GDPR and DPDP (Digital Personal Data Protection) regulations
2. WHEN a User uploads documents without providing storage consent, THE System SHALL delete the documents after 30 days
3. WHEN a User provides storage consent, THE System SHALL retain documents according to the consent terms
4. THE System SHALL encrypt all document data in transit and at rest

### Requirement 11: Data Source Integration

**User Story:** As a system administrator, I want the system to maintain up-to-date government data, so that users receive accurate compliance information.

#### Acceptance Criteria

1. THE System SHALL load CBIC HSN code master list into the database
2. THE System SHALL scrape DGFT trade notices weekly and update the RAG pipeline
3. THE System SHALL maintain Ministry of Commerce export scheme guidelines in structured format
4. WHEN government data sources are updated, THE System SHALL refresh cached data within 24 hours

### Requirement 12: Web Application Interface

**User Story:** As an exporter, I want to access the system through a mobile-friendly web interface, so that I have an alternative to WhatsApp when needed.

#### Acceptance Criteria

1. THE System SHALL provide a React-based web application with mobile-first responsive design
2. WHEN a User accesses the web app on mobile, THE System SHALL display an optimized mobile interface
3. THE System SHALL support voice input through browser microphone API
4. THE System SHALL support document upload via drag-and-drop and camera capture
5. WHEN a User uploads a document via camera, THE System SHALL optimize image quality for OCR processing
