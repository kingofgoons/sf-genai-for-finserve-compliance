-- =============================================================================
-- 00_SETUP.SQL
-- Snowflake GenAI for Financial Services Compliance
-- 
-- Creates database, tables, sample emails, and stage-based attachments.
-- Run this FIRST before other worksheets.
-- =============================================================================

-- Set context
USE ROLE ACCOUNTADMIN;  -- Or role with CREATE DATABASE

CREATE DATABASE IF NOT EXISTS GENAI_COMPLIANCE_DEMO;
USE DATABASE GENAI_COMPLIANCE_DEMO;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

CREATE WAREHOUSE IF NOT EXISTS GENAI_HOL_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- STAGE FOR ATTACHMENTS
-- In production, actual files would be uploaded here
-- =============================================================================

CREATE OR REPLACE STAGE compliance_attachments
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for email attachments (images, documents, spreadsheets)';

-- =============================================================================
-- TABLES
-- =============================================================================

-- Emails for compliance monitoring
CREATE OR REPLACE TABLE compliance_emails (
    email_id            INTEGER PRIMARY KEY,
    sender              VARCHAR(200),
    recipient           VARCHAR(200),
    subject             VARCHAR(500),
    email_content       TEXT,
    has_attachment      BOOLEAN DEFAULT FALSE,
    trader_id           VARCHAR(50),
    department          VARCHAR(100),
    received_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Email attachments with stage file paths
CREATE OR REPLACE TABLE email_attachments (
    attachment_id   INTEGER PRIMARY KEY,
    email_id        INTEGER REFERENCES compliance_emails(email_id),
    filename        VARCHAR(255),
    file_type       VARCHAR(50),
    stage_path      VARCHAR(500),  -- Path to file on stage: @compliance_attachments/...
    file_size_kb    INTEGER,
    uploaded_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- For demo purposes: text description of image content
    -- In production, CORTEX.COMPLETE would analyze actual image bytes
    image_description TEXT
);

-- =============================================================================
-- SAMPLE EMAILS
-- =============================================================================

INSERT INTO compliance_emails VALUES
    -- Email 1: German - Insider trading (tests AI_TRANSLATE)
    (1,
     'hans.mueller@external.de',
     'john.smith@acmefinance.com',
     'Vertrauliche Information - Dringend',
     'Ich habe vertrauliche Informationen über die bevorstehende Fusion zwischen TechCorp und MegaSoft erhalten. Die Ankündigung erfolgt am Montag vor Börseneröffnung. Wir sollten schnell handeln und unsere Positionen entsprechend anpassen. Bitte diese Information nicht weitergeben.',
     FALSE,
     'TRADER_001',
     'Trading',
     CURRENT_TIMESTAMP()),

    -- Email 2: English - Insider trading WITH ATTACHMENT
    (2,
     'sarah.jones@acmefinance.com',
     'mike.chen@acmefinance.com',
     'RE: AAPL Position - See Attached Analysis',
     'Hey Mike, just got off the phone with my contact at Apple. They are announcing earnings beat tomorrow - way above consensus. I ran the numbers in the attached spreadsheet. We should load up on calls before close today. Don''t tell anyone else on the desk. Delete this after reading.',
     TRUE,
     'TRADER_002',
     'Trading',
     CURRENT_TIMESTAMP()),

    -- Email 3: English - Market manipulation WITH SCREENSHOT
    (3,
     'trading.desk@acmefinance.com',
     'group-traders@acmefinance.com',
     'URGENT: Coordinated Strategy - Screenshot of Setup',
     'Team, let''s coordinate our NVDA trades today. I''ve attached a screenshot of the order entry system with the timing. Everyone buy at 10:15 AM sharp to push the price up, then we sell into the momentum around 2 PM. Target is $15 profit per share. Delete this email and the screenshot after viewing.',
     TRUE,
     'TRADER_003',
     'Trading',
     CURRENT_TIMESTAMP()),

    -- Email 4: English - Clean/normal (no attachment)
    (4,
     'compliance@acmefinance.com',
     'all-staff@acmefinance.com',
     'Q4 Compliance Training Reminder',
     'This is a reminder that all employees must complete the mandatory Q4 compliance training by December 15th. The training covers updated regulations on insider trading prevention, client data protection, and communications monitoring. Please access the training portal through the company intranet. Thank you for your cooperation.',
     FALSE,
     NULL,
     'Compliance',
     CURRENT_TIMESTAMP()),

    -- Email 5: French - Data exfiltration WITH ARCHITECTURE DIAGRAM
    (5,
     'pierre.dubois@acmefinance.com',
     'external.consultant@gmail.com',
     'Documents demandés - Architecture interne',
     'Voici les fichiers que vous avez demandés. J''ai inclus notre diagramme d''architecture interne montrant tous les systèmes de trading et les connexions aux bourses. Aussi les numéros de compte clients et les soldes. Veuillez les supprimer après utilisation car ces documents sont strictement confidentiels.',
     TRUE,
     'ANALYST_001',
     'Research',
     CURRENT_TIMESTAMP());

-- =============================================================================
-- SAMPLE ATTACHMENTS (Stage-based paths)
-- In production: actual files uploaded to @compliance_attachments
-- For demo: image_description simulates what the image contains
-- =============================================================================

INSERT INTO email_attachments VALUES
    -- Attachment for Email 2: Spreadsheet with insider analysis
    (1, 2,
     'AAPL_Insider_Analysis.xlsx',
     'spreadsheet',
     '@compliance_attachments/2024/12/AAPL_Insider_Analysis.xlsx',
     245,
     CURRENT_TIMESTAMP(),
     'Excel spreadsheet showing Apple Inc stock analysis. Contains columns labeled: "Insider Source", "Expected EPS", "Consensus EPS", "Trade Recommendation". A cell is highlighted in yellow showing "BUY BEFORE ANNOUNCEMENT". The footer contains text: "CONFIDENTIAL - DO NOT DISTRIBUTE". There is a chart showing expected stock price movement with an arrow pointing up labeled "Post-Announcement Target".'),

    -- Attachment for Email 3: Screenshot of trading system
    (2, 3,
     'order_entry_screenshot.png',
     'image/png',
     '@compliance_attachments/2024/12/order_entry_screenshot.png',
     1024,
     CURRENT_TIMESTAMP(),
     'Screenshot of Bloomberg terminal order entry screen. The screen shows a list of pending orders for NVDA (NVIDIA Corporation). All orders have the same entry time of 10:15:00 AM. There are 8 separate order tickets visible, each from a different trader ID. A handwritten red annotation in the corner reads "COORDINATE WITH TEAM - SAME TIME". Trading account numbers are partially visible. The total order value shown is approximately $2.4 million.'),

    -- Attachment for Email 5: Internal architecture diagram
    (3, 5,
     'trading_infrastructure_v3.pdf',
     'application/pdf',
     '@compliance_attachments/2024/12/trading_infrastructure_v3.pdf',
     2048,
     CURRENT_TIMESTAMP(),
     'Network architecture diagram with title "ACME Finance - Trading Infrastructure v3.0". The diagram shows connections between multiple systems: Internal Trading Engine (IP: 10.0.1.50), NYSE Direct Feed (connection ID visible), NASDAQ Direct Feed, Client Portfolio Database (server name: PROD-DB-01), Risk Management System, and Backup Data Center. AWS account ID "123456789012" is visible in the corner. A large red watermark across the page reads "INTERNAL USE ONLY - NOT FOR EXTERNAL DISTRIBUTION". The document footer shows "Last updated: November 2024 - Classification: HIGHLY CONFIDENTIAL".');

-- =============================================================================
-- VERIFY SETUP
-- =============================================================================

SELECT '✅ Setup complete!' AS status;

-- Summary counts
SELECT 'compliance_emails' AS table_name, COUNT(*) AS rows FROM compliance_emails
UNION ALL 
SELECT 'email_attachments', COUNT(*) FROM email_attachments;

-- Preview emails
SELECT 
    email_id, 
    sender,
    subject,
    has_attachment,
    LEFT(email_content, 50) || '...' AS preview
FROM compliance_emails
ORDER BY email_id;

-- Preview attachments with stage paths
SELECT 
    a.attachment_id,
    a.email_id,
    a.filename,
    a.file_type,
    a.stage_path,
    a.file_size_kb || ' KB' AS size
FROM email_attachments a;

-- Show which emails have attachments
SELECT 
    e.email_id,
    e.subject,
    e.has_attachment,
    a.filename,
    a.stage_path
FROM compliance_emails e
LEFT JOIN email_attachments a ON e.email_id = a.email_id
ORDER BY e.email_id;
