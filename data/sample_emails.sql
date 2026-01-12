-- =============================================================================
-- Sample Email Dataset for GenAI Compliance Demo
-- Demonstrates: AI SQL functions for email communications monitoring
-- Note: Start with <5 emails, including non-English for AI_TRANSLATE demo
-- =============================================================================

-- Create demo database and schema (idempotent)
CREATE DATABASE IF NOT EXISTS GENAI_COMPLIANCE_DEMO;
USE DATABASE GENAI_COMPLIANCE_DEMO;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- =============================================================================
-- Core Tables
-- =============================================================================

-- Main email table for compliance monitoring
CREATE OR REPLACE TABLE compliance_emails (
    email_id            INTEGER AUTOINCREMENT PRIMARY KEY,
    sender              VARCHAR(200),
    recipient           VARCHAR(200),
    subject             VARCHAR(500),
    email_content       TEXT,
    original_language   VARCHAR(10) DEFAULT 'en',
    trader_id           VARCHAR(50),
    department          VARCHAR(100),
    ingestion_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    compliance_flag     BOOLEAN DEFAULT FALSE
);

-- Email attachments for multimodal demo
CREATE OR REPLACE TABLE email_attachments (
    attachment_id   INTEGER AUTOINCREMENT PRIMARY KEY,
    email_id        INTEGER REFERENCES compliance_emails(email_id),
    filename        VARCHAR(255),
    file_type       VARCHAR(50),
    file_size_kb    INTEGER,
    attachment_url  VARCHAR(1000),  -- Stage URL for actual files
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Historical violations for similarity matching
CREATE OR REPLACE TABLE historical_violations (
    violation_id    INTEGER AUTOINCREMENT PRIMARY KEY,
    violation_type  VARCHAR(100),
    email_content   TEXT,
    detected_date   DATE,
    resolution      VARCHAR(500)
);

-- Compliance incidents for aggregation demo
CREATE OR REPLACE TABLE compliance_incidents (
    incident_id         INTEGER AUTOINCREMENT PRIMARY KEY,
    department          VARCHAR(100),
    incident_description TEXT,
    incident_date       DATE,
    severity            VARCHAR(20)
);

-- Recorded calls for transcription demo
CREATE OR REPLACE TABLE recorded_calls (
    call_id     INTEGER AUTOINCREMENT PRIMARY KEY,
    trader_id   VARCHAR(50),
    call_date   DATE,
    duration_sec INTEGER,
    audio_file  VARCHAR(1000)  -- Stage URL for audio files
);

-- =============================================================================
-- Sample Data: Start with <5 emails (per demo plan)
-- First email is non-English to demonstrate AI_TRANSLATE
-- =============================================================================

INSERT INTO compliance_emails (sender, recipient, subject, email_content, original_language, trader_id, department, compliance_flag)
VALUES
    -- Email 1: German (for AI_TRANSLATE demo) - Suspicious
    ('hans.mueller@external.de',
     'john.smith@acmefinance.com',
     'Vertrauliche Information - Dringend',
     'Ich habe vertrauliche Informationen über die bevorstehende Fusion zwischen TechCorp und MegaSoft erhalten. Die Ankündigung erfolgt am Montag vor Börseneröffnung. Wir sollten schnell handeln und unsere Positionen entsprechend anpassen. Bitte diese Information nicht weitergeben.',
     'de',
     'TRADER_001',
     'Trading',
     TRUE),

    -- Email 2: English - Clear insider trading
    ('sarah.jones@acmefinance.com',
     'mike.chen@acmefinance.com',
     'RE: AAPL Position',
     'Hey Mike, just got off the phone with my contact at Apple. They''re announcing earnings beat tomorrow - way above consensus. We should load up on calls before close today. Don''t tell anyone else on the desk.',
     'en',
     'TRADER_002',
     'Trading',
     TRUE),

    -- Email 3: English - Market manipulation discussion
    ('trading.desk@acmefinance.com',
     'group-traders@acmefinance.com',
     'Coordinated Trading Strategy - URGENT',
     'Team, let''s coordinate our NVDA trades today. Everyone buy at 10:15 AM sharp to push the price up, then we''ll sell into the momentum around 2 PM. Target is $15 profit per share. Delete this email after reading.',
     'en',
     'TRADER_003',
     'Trading',
     TRUE),

    -- Email 4: English - Clean/normal business email
    ('compliance@acmefinance.com',
     'all-staff@acmefinance.com',
     'Q4 Compliance Training Reminder',
     'This is a reminder that all employees must complete the mandatory Q4 compliance training by December 15th. The training covers updated regulations on insider trading prevention, client data protection, and communications monitoring. Please access the training portal through the company intranet.',
     'en',
     NULL,
     'Compliance',
     FALSE),

    -- Email 5: French - Data exfiltration concern
    ('pierre.dubois@acmefinance.com',
     'external.consultant@gmail.com',
     'Documents demandés',
     'Voici les fichiers clients que vous avez demandés. J''ai inclus les numéros de compte, les soldes et les informations personnelles. Veuillez les supprimer après utilisation car je ne devrais pas partager ces données en dehors de l''entreprise.',
     'fr',
     'ANALYST_001',
     'Research',
     TRUE);

-- =============================================================================
-- Sample Historical Violations (for AI_SIMILARITY demo)
-- =============================================================================

INSERT INTO historical_violations (violation_type, email_content, detected_date, resolution)
VALUES
    ('insider_trading',
     'Got a tip from the board meeting - they''re approving the buyback program next week. Load up on shares now before the announcement.',
     '2024-03-15',
     'Employee terminated, reported to SEC'),

    ('market_manipulation',
     'Let''s all buy XYZ stock at the same time tomorrow morning to drive the price up. Sell at noon.',
     '2024-06-22',
     'Trading privileges suspended, formal warning'),

    ('data_exfiltration',
     'Sending you the client list with all their portfolio details. Use your personal email so IT doesn''t flag it.',
     '2024-08-10',
     'Employee terminated, legal review initiated');

-- =============================================================================
-- Sample Compliance Incidents (for AI_AGG demo)
-- =============================================================================

INSERT INTO compliance_incidents (department, incident_description, incident_date, severity)
VALUES
    ('Trading', 'Trader executed personal trades in securities also held in client accounts without proper disclosure.', '2024-09-01', 'HIGH'),
    ('Trading', 'Suspicious pattern of trades immediately before major announcements. Under investigation.', '2024-09-15', 'CRITICAL'),
    ('Research', 'Analyst shared draft research report with external party before publication.', '2024-10-01', 'HIGH'),
    ('Research', 'Failure to maintain information barriers between research and trading desks.', '2024-10-20', 'MEDIUM'),
    ('Operations', 'Client data accessed without documented business need. Access logs under review.', '2024-11-01', 'HIGH'),
    ('Operations', 'Delayed suspicious activity report filing - missed 15-day deadline.', '2024-11-10', 'MEDIUM');

-- =============================================================================
-- Sample Attachments (metadata only - actual files would be in a stage)
-- =============================================================================

INSERT INTO email_attachments (email_id, filename, file_type, file_size_kb, attachment_url)
VALUES
    (2, 'AAPL_Analysis.xlsx', 'spreadsheet', 245, '@compliance_stage/attachments/aapl_analysis.xlsx'),
    (3, 'trading_schedule.pdf', 'document', 128, '@compliance_stage/attachments/trading_schedule.pdf'),
    (5, 'client_export.csv', 'data', 1024, '@compliance_stage/attachments/client_export.csv');

-- =============================================================================
-- Verify data loaded
-- =============================================================================

SELECT 'compliance_emails' AS table_name, COUNT(*) AS row_count FROM compliance_emails
UNION ALL
SELECT 'historical_violations', COUNT(*) FROM historical_violations
UNION ALL
SELECT 'compliance_incidents', COUNT(*) FROM compliance_incidents
UNION ALL
SELECT 'email_attachments', COUNT(*) FROM email_attachments;

-- Preview emails
SELECT email_id, original_language, sender, subject, LEFT(email_content, 80) || '...' AS preview
FROM compliance_emails
LIMIT 5;

COMMENT ON TABLE compliance_emails IS 'Sample compliance emails for GenAI demo - synthetic data only';

