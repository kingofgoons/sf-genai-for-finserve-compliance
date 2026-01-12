-- =============================================================================
-- 00_SETUP.SQL
-- Snowflake GenAI for Financial Services Compliance - Hands-on Lab
-- 
-- This worksheet creates the database, schema, and sample data for the demo.
-- Run this FIRST before proceeding to other worksheets.
-- =============================================================================

-- Set context
USE ROLE ACCOUNTADMIN;  -- Or a role with CREATE DATABASE privileges

-- Create demo database and schema
CREATE DATABASE IF NOT EXISTS GENAI_COMPLIANCE_DEMO;
USE DATABASE GENAI_COMPLIANCE_DEMO;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- Create warehouse if needed (adjust size as appropriate)
CREATE WAREHOUSE IF NOT EXISTS GENAI_HOL_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- TABLES
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

-- =============================================================================
-- SAMPLE DATA: 5 emails (including non-English for AI_TRANSLATE demo)
-- =============================================================================

INSERT INTO compliance_emails 
    (sender, recipient, subject, email_content, original_language, trader_id, department, compliance_flag)
VALUES
    -- Email 1: German - Suspicious insider trading
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

    -- Email 3: English - Market manipulation
    ('trading.desk@acmefinance.com',
     'group-traders@acmefinance.com',
     'Coordinated Trading Strategy - URGENT',
     'Team, let''s coordinate our NVDA trades today. Everyone buy at 10:15 AM sharp to push the price up, then we''ll sell into the momentum around 2 PM. Target is $15 profit per share. Delete this email after reading.',
     'en',
     'TRADER_003',
     'Trading',
     TRUE),

    -- Email 4: English - Clean/normal
    ('compliance@acmefinance.com',
     'all-staff@acmefinance.com',
     'Q4 Compliance Training Reminder',
     'This is a reminder that all employees must complete the mandatory Q4 compliance training by December 15th. The training covers updated regulations on insider trading prevention, client data protection, and communications monitoring. Please access the training portal through the company intranet.',
     'en',
     NULL,
     'Compliance',
     FALSE),

    -- Email 5: French - Data exfiltration
    ('pierre.dubois@acmefinance.com',
     'external.consultant@gmail.com',
     'Documents demandés',
     'Voici les fichiers clients que vous avez demandés. J''ai inclus les numéros de compte, les soldes et les informations personnelles. Veuillez les supprimer après utilisation car je ne devrais pas partager ces données en dehors de l''entreprise.',
     'fr',
     'ANALYST_001',
     'Research',
     TRUE);

-- Historical violations for similarity demo
INSERT INTO historical_violations (violation_type, email_content, detected_date, resolution)
VALUES
    ('insider_trading',
     'Got a tip from the board meeting - they''re approving the buyback program next week. Load up on shares now before the announcement.',
     '2024-03-15',
     'Employee terminated, reported to SEC'),
     
    ('market_manipulation',
     'Let''s all buy XYZ stock at the same time tomorrow morning to drive the price up. Sell at noon.',
     '2024-06-22',
     'Trading privileges suspended, formal warning');

-- Compliance incidents for aggregation demo
INSERT INTO compliance_incidents (department, incident_description, incident_date, severity)
VALUES
    ('Trading', 'Trader executed personal trades in securities also held in client accounts without proper disclosure.', '2024-09-01', 'HIGH'),
    ('Trading', 'Suspicious pattern of trades immediately before major announcements. Under investigation.', '2024-09-15', 'CRITICAL'),
    ('Research', 'Analyst shared draft research report with external party before publication.', '2024-10-01', 'HIGH'),
    ('Research', 'Failure to maintain information barriers between research and trading desks.', '2024-10-20', 'MEDIUM'),
    ('Operations', 'Client data accessed without documented business need. Access logs under review.', '2024-11-01', 'HIGH'),
    ('Operations', 'Delayed suspicious activity report filing - missed 15-day deadline.', '2024-11-10', 'MEDIUM');

-- =============================================================================
-- VERIFY SETUP
-- =============================================================================

SELECT '✓ Setup complete!' AS status;

SELECT 'compliance_emails' AS table_name, COUNT(*) AS rows FROM compliance_emails
UNION ALL SELECT 'historical_violations', COUNT(*) FROM historical_violations
UNION ALL SELECT 'compliance_incidents', COUNT(*) FROM compliance_incidents;

-- Preview the emails
SELECT 
    email_id, 
    original_language AS lang, 
    sender, 
    subject,
    LEFT(email_content, 60) || '...' AS preview
FROM compliance_emails;

