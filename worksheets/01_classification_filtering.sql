-- =============================================================================
-- 01_CLASSIFICATION_FILTERING.SQL
-- Demo Block 1: Text Classification & Filtering (15 min)
-- 
-- Functions covered:
--   • AI_CLASSIFY - Categorize text into defined classes
--   • AI_FILTER   - Boolean filtering with natural language questions
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- AI_CLASSIFY: Zero-shot text classification
-- No training data required - define categories and classify immediately
-- =============================================================================

-- Example 1: Classify a single email
SELECT 
    AI_CLASSIFY(
        'Hey Mike, just got off the phone with my contact at Apple. They''re announcing earnings beat tomorrow. We should load up on calls before close today.',
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ) AS classification;

-- Example 2: Classify all emails in the table
SELECT 
    email_id,
    sender,
    subject,
    AI_CLASSIFY(
        email_content,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ) AS risk_category
FROM compliance_emails;

-- Example 3: Extract just the predicted class and confidence
SELECT 
    email_id,
    subject,
    AI_CLASSIFY(
        email_content,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS predicted_class,
    AI_CLASSIFY(
        email_content,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):confidence::FLOAT AS confidence_score
FROM compliance_emails;

-- =============================================================================
-- AI_FILTER: Natural language boolean filtering
-- Ask yes/no questions in plain English
-- =============================================================================

-- Example 1: Filter for emails mentioning non-public information
SELECT 
    email_id,
    sender,
    subject,
    AI_FILTER(
        email_content, 
        'Does this email mention non-public or confidential information?'
    ) AS mentions_confidential
FROM compliance_emails;

-- Example 2: Use AI_FILTER in WHERE clause to find suspicious emails
SELECT 
    email_id,
    sender,
    subject,
    LEFT(email_content, 100) || '...' AS preview
FROM compliance_emails
WHERE AI_FILTER(email_content, 'Does this mention non-public information?') = TRUE;

-- Example 3: Multiple filter conditions
SELECT 
    email_id,
    sender,
    subject,
    AI_FILTER(email_content, 'Are specific stock tickers or securities mentioned?') AS has_tickers,
    AI_FILTER(email_content, 'Does this suggest urgency or time-sensitive action?') AS is_urgent,
    AI_FILTER(email_content, 'Is there a request to delete or hide information?') AS delete_request
FROM compliance_emails;

-- =============================================================================
-- COMBINED: Classification + Filtering Pipeline
-- Real-world compliance monitoring pattern
-- =============================================================================

SELECT 
    email_id,
    sender,
    recipient,
    subject,
    
    -- Classification
    AI_CLASSIFY(
        email_content,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS risk_category,
    
    -- Multiple filter flags
    AI_FILTER(email_content, 'Does this mention non-public information?') AS material_info_flag,
    AI_FILTER(email_content, 'Are specific trade amounts or prices mentioned?') AS trade_details_flag,
    AI_FILTER(email_content, 'Is there instruction to delete or keep secret?') AS concealment_flag,
    
    -- Priority scoring based on flags
    CASE 
        WHEN AI_FILTER(email_content, 'Is there instruction to delete or keep secret?') THEN 'CRITICAL'
        WHEN AI_FILTER(email_content, 'Does this mention non-public information?') THEN 'HIGH'
        ELSE 'NORMAL'
    END AS review_priority
    
FROM compliance_emails
ORDER BY 
    CASE review_priority 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        ELSE 3 
    END;

-- =============================================================================
-- TRY IT YOURSELF
-- Modify the categories or filter questions below
-- =============================================================================

-- Your turn: Add your own classification categories
SELECT 
    email_id,
    subject,
    AI_CLASSIFY(
        email_content,
        ['urgent_review', 'routine', 'external_communication', 'internal_memo']
    ) AS custom_category
FROM compliance_emails;

-- Your turn: Write your own filter question
SELECT 
    email_id,
    subject,
    AI_FILTER(email_content, 'YOUR QUESTION HERE') AS your_filter
FROM compliance_emails;

