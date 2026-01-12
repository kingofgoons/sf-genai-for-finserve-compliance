-- =============================================================================
-- Sample Compliance Documents for GenAI Demo
-- Demonstrates: Loading mock data for Cortex AI processing
-- =============================================================================

-- Create demo database and schema (idempotent)
CREATE DATABASE IF NOT EXISTS GENAI_COMPLIANCE_DEMO;
USE DATABASE GENAI_COMPLIANCE_DEMO;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- Table for compliance documents
CREATE OR REPLACE TABLE compliance_docs (
    doc_id          INTEGER AUTOINCREMENT PRIMARY KEY,
    doc_type        VARCHAR(50),
    title           VARCHAR(500),
    content         TEXT,
    effective_date  DATE,
    department      VARCHAR(100),
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert sample compliance documents (synthetic/mock data)
INSERT INTO compliance_docs (doc_type, title, content, effective_date, department)
VALUES
    ('POLICY', 'Data Retention Policy', 
     'All customer personally identifiable information (PII) must be retained for a minimum of 7 years from the date of account closure. Data must be stored in encrypted format using AES-256 encryption. Access to PII data requires manager approval and must be logged in the audit system. Violations may result in fines up to $50,000 per incident.',
     '2024-01-01', 'Compliance'),
    
    ('POLICY', 'Anti-Money Laundering (AML) Policy',
     'All transactions exceeding $10,000 must be reported to FinCEN within 15 days. Suspicious activity reports (SARs) must be filed for any transaction that appears to involve funds derived from illegal activity. Customer due diligence must be performed for all new accounts. Enhanced due diligence required for high-risk customers including PEPs.',
     '2024-01-15', 'Risk Management'),
    
    ('REGULATION', 'GDPR Data Subject Rights',
     'Data subjects have the right to access, rectify, and erase their personal data. Requests must be fulfilled within 30 days. Data portability must be provided in machine-readable format. Right to object to automated decision-making including profiling. Failure to comply may result in fines up to 4% of annual global revenue.',
     '2023-06-01', 'Legal'),
    
    ('AUDIT_FINDING', 'Q3 2024 Access Control Audit',
     'Finding: 23 user accounts with elevated privileges have not been reviewed in over 90 days. Risk Level: High. Recommendation: Implement quarterly access reviews for all privileged accounts. Remediation deadline: 2024-12-31. Owner: IT Security team.',
     '2024-10-15', 'Internal Audit'),
    
    ('POLICY', 'Vendor Risk Management',
     'All third-party vendors with access to customer data must complete security questionnaires annually. Vendors must maintain SOC 2 Type II certification. Critical vendors require on-site audits every 2 years. Vendor contracts must include right-to-audit clauses and data breach notification requirements within 24 hours.',
     '2024-03-01', 'Procurement');

-- Optional: Create embeddings table for RAG demo
-- Requires Cortex EMBED function access
CREATE OR REPLACE TABLE compliance_docs_with_embeddings AS
SELECT 
    doc_id,
    doc_type,
    title,
    content,
    effective_date,
    department,
    -- Uncomment when running in Snowflake with Cortex access:
    -- SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', content) AS embedding
    NULL::ARRAY AS embedding  -- Placeholder for demo
FROM compliance_docs;

-- Verify data loaded (limit for demo display)
SELECT doc_type, title, LEFT(content, 100) || '...' AS content_preview
FROM compliance_docs
LIMIT 5;

COMMENT ON TABLE compliance_docs IS 'Sample compliance documents for GenAI demo - synthetic data only';

