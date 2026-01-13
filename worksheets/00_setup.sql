-- =============================================================================
-- 00_SETUP.SQL
-- Snowflake GenAI for Financial Services Compliance
-- 
-- Creates database, tables, sample emails, and stage-based attachments.
-- Run this FIRST before other worksheets.
-- =============================================================================

-- =============================================================================
-- ACCOUNTADMIN SECTION: Create resources and role (run once)
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Create database and warehouse
CREATE DATABASE IF NOT EXISTS GENAI_COMPLIANCE_DEMO;
CREATE WAREHOUSE IF NOT EXISTS GENAI_HOL_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

-- Create custom role for this demo
CREATE ROLE IF NOT EXISTS GENAI_COMPLIANCE_ROLE;

-- Grant privileges to custom role
GRANT USAGE ON DATABASE GENAI_COMPLIANCE_DEMO TO ROLE GENAI_COMPLIANCE_ROLE;
GRANT USAGE ON SCHEMA GENAI_COMPLIANCE_DEMO.PUBLIC TO ROLE GENAI_COMPLIANCE_ROLE;
GRANT CREATE TABLE ON SCHEMA GENAI_COMPLIANCE_DEMO.PUBLIC TO ROLE GENAI_COMPLIANCE_ROLE;
GRANT CREATE VIEW ON SCHEMA GENAI_COMPLIANCE_DEMO.PUBLIC TO ROLE GENAI_COMPLIANCE_ROLE;
GRANT CREATE STAGE ON SCHEMA GENAI_COMPLIANCE_DEMO.PUBLIC TO ROLE GENAI_COMPLIANCE_ROLE;
GRANT USAGE ON WAREHOUSE GENAI_HOL_WH TO ROLE GENAI_COMPLIANCE_ROLE;

-- Grant Cortex AI access (required for AI SQL functions)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE GENAI_COMPLIANCE_ROLE;

-- Grant role to current user (replace <YOUR_USERNAME> or run separately)
-- Option 1: Replace with your username
-- GRANT ROLE GENAI_COMPLIANCE_ROLE TO USER your_username;

-- Option 2: Use EXECUTE IMMEDIATE with current user
SET my_user = (SELECT CURRENT_USER());
GRANT ROLE GENAI_COMPLIANCE_ROLE TO USER IDENTIFIER($my_user);


-- =============================================================================
-- SWITCH TO CUSTOM ROLE: All remaining operations use least-privilege
-- =============================================================================
USE ROLE GENAI_COMPLIANCE_ROLE;
USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- STAGE FOR ATTACHMENTS
-- In production, actual files would be uploaded here
-- =============================================================================

CREATE OR REPLACE STAGE compliance_attachments
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')  -- Server-side encryption required for AI_COMPLETE
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
    lang                VARCHAR(10),  -- Detected language code (en, de, fr, etc.)
    has_attachment      BOOLEAN DEFAULT FALSE,
    trader_id           VARCHAR(50),
    department          VARCHAR(100),
    received_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- AI Analysis columns (populated in 01_building_blocks.sql)
    en_content          TEXT DEFAULT NULL,         -- English translation (or original if already English)
    sentiment           VARIANT DEFAULT NULL,      -- AI_SENTIMENT results
    classification      VARIANT DEFAULT NULL,      -- AI_CLASSIFY results  
    extracted_info      VARIANT DEFAULT NULL,      -- AI_EXTRACT results
    compliance_flag     VARCHAR(50) DEFAULT NULL,  -- Derived: CRITICAL, SENSITIVE, CLEAN
    violations_list     VARCHAR(500) DEFAULT NULL  -- Comma-separated violation labels
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
    image_description TEXT,
    
    -- AI Analysis columns (populated in 02_aisql_approach.sql)
    classification      VARIANT DEFAULT NULL,      -- AI_CLASSIFY results
    extracted_info      VARIANT DEFAULT NULL,      -- AI_EXTRACT results
    compliance_flag     VARCHAR(50) DEFAULT NULL,  -- SENSITIVE or CLEAN
    violations_list     VARCHAR(500) DEFAULT NULL  -- Comma-separated violation labels
);

-- =============================================================================
-- SAMPLE EMAILS
-- =============================================================================

INSERT INTO compliance_emails 
    (email_id, sender, recipient, subject, email_content, lang, has_attachment, trader_id, department, received_at)
VALUES
    -- Email 1: German - Insider trading (tests AI_TRANSLATE) - urgency + secrecy
    (1,
     'hans.mueller@external.de',
     'john.smith@acmefinance.com',
     'STRENG GEHEIM - Sofort handeln!',
     'DRINGEND! Du MUSST sofort handeln! Ich habe absolut vertrauliche Informationen über die Fusion zwischen TechCorp und MegaSoft. Die Ankündigung kommt Montag VOR Börseneröffnung. Kaufe JETZT so viel wie möglich! Erzähl NIEMANDEM davon - nicht deinem Chef, nicht Compliance, NIEMANDEM. Lösche diese Nachricht sofort nach dem Lesen. Wenn das rauskommt, sind wir beide erledigt.',
     NULL,  -- Language will be detected in 01_building_blocks.sql
     FALSE,
     'TRADER_001',
     'Trading',
     CURRENT_TIMESTAMP()),

    -- Email 2: English - Insider trading WITH ATTACHMENT (friendly tone, still violating!)
    (2,
     'sarah.jones@acmefinance.com',
     'mike.chen@acmefinance.com',
     'RE: AAPL Position - Thought you''d want to know :)',
     'Hey Mike! Hope you''re having a great day! So I was chatting with my friend at Apple over drinks last night and she let slip that earnings are going to be WAY better than anyone expects - like, blow-out numbers! I put together a little analysis in the attached spreadsheet. Thought you might want to get in before the announcement tomorrow morning! Just keep this between us though, okay? My friend could get in trouble. Maybe delete this after you read it. Anyway, hope this helps! Let''s grab lunch soon! 😊',
     NULL,
     TRUE,
     'TRADER_002',
     'Trading',
     CURRENT_TIMESTAMP()),

    -- Email 3: English - Market manipulation WITH SCREENSHOT (high pressure, secrecy)
    (3,
     'trading.desk@acmefinance.com',
     'group-traders@acmefinance.com',
     'MANDATORY: Coordinated Strategy - DO NOT FORWARD',
     'This is NOT optional. Every single one of you MUST participate or you''re off the desk. Here''s the plan: we all hit NVDA at exactly 10:15 AM - no exceptions. I''ve attached the setup screenshot. Buy hard to push the price, then we dump at 2 PM into retail. If ANYONE breathes a word of this outside this group, I will personally make sure you never work in finance again. This conversation NEVER happened. Destroy all evidence after reading. I''m watching the order flow - I''ll know if you don''t comply.',
     NULL,
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
     NULL,
     FALSE,
     NULL,
     'Compliance',
     CURRENT_TIMESTAMP()),

    -- Email 5: French - Data exfiltration WITH ARCHITECTURE DIAGRAM (secrecy)
    (5,
     'pierre.dubois@acmefinance.com',
     'external.consultant@gmail.com',
     'CONFIDENTIEL - Ne pas transférer',
     'Voici les documents que tu as demandés - mais tu ne les as JAMAIS reçus de moi, compris? J''ai inclus notre architecture interne complète avec TOUS les systèmes de trading, les connexions aux bourses, les adresses IP internes, et les informations de compte clients. C''est STRICTEMENT INTERDIT de partager ça à l''extérieur. Supprime cet email IMMÉDIATEMENT après téléchargement. Si quelqu''un découvre que c''est moi qui t''ai envoyé ça, je perds mon emploi. On ne s''est jamais parlé.',
     NULL,
     TRUE,
     'ANALYST_001',
     'Research',
     CURRENT_TIMESTAMP());

-- =============================================================================
-- SAMPLE ATTACHMENTS (Stage-based paths)
-- In production: actual files uploaded to @compliance_attachments
-- For demo: image_description simulates what the image contains
-- =============================================================================

INSERT INTO email_attachments 
    (attachment_id, email_id, filename, file_type, stage_path, file_size_kb, image_description)
VALUES
    -- Attachment for Email 2: Spreadsheet with insider analysis
    (1, 2,
     'AAPL_Insider_Analysis.xlsx',
     'spreadsheet',
     '@compliance_attachments/2024/12/AAPL_Insider_Analysis.xlsx',
     245,
     'Excel spreadsheet showing Apple Inc stock analysis. Contains columns labeled: "Insider Source", "Expected EPS", "Consensus EPS", "Trade Recommendation". A cell is highlighted in yellow showing "BUY BEFORE ANNOUNCEMENT". The footer contains text: "CONFIDENTIAL - DO NOT DISTRIBUTE". There is a chart showing expected stock price movement with an arrow pointing up labeled "Post-Announcement Target".'),

    -- Attachment for Email 3: Screenshot of trading system
    (2, 3,
     'order_entry_screenshot.png',
     'image/png',
     '@compliance_attachments/2024/12/order_entry_screenshot.png',
     1024,
     'Screenshot of Bloomberg terminal order entry screen. The screen shows a list of pending orders for NVDA (NVIDIA Corporation). All orders have the same entry time of 10:15:00 AM. There are 8 separate order tickets visible, each from a different trader ID. A handwritten red annotation in the corner reads "COORDINATE WITH TEAM - SAME TIME". Trading account numbers are partially visible. The total order value shown is approximately $2.4 million.'),

    -- Attachment for Email 5: Internal architecture diagram
    (3, 5,
     'trading_infrastructure_v3.pdf',
     'application/pdf',
     '@compliance_attachments/2024/12/trading_infrastructure_v3.pdf',
     2048,
     'Network architecture diagram with title "ACME Finance - Trading Infrastructure v3.0". The diagram shows connections between multiple systems: Internal Trading Engine (IP: 10.0.1.50), NYSE Direct Feed (connection ID visible), NASDAQ Direct Feed, Client Portfolio Database (server name: PROD-DB-01), Risk Management System, and Backup Data Center. AWS account ID "123456789012" is visible in the corner. A large red watermark across the page reads "INTERNAL USE ONLY - NOT FOR EXTERNAL DISTRIBUTION". The document footer shows "Last updated: November 2024 - Classification: HIGHLY CONFIDENTIAL".');

-- =============================================================================
-- VERIFY SETUP
-- =============================================================================

SELECT '✅ Setup complete!' AS status;

-- Summary counts
SELECT 'compliance_emails' AS table_name, COUNT(*) AS row_count FROM compliance_emails
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
