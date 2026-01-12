-- =============================================================================
-- 02_EXTRACTION_SENTIMENT.SQL
-- Demo Block 2: Information Extraction & Sentiment (15 min)
-- 
-- Functions covered:
--   • AI_EXTRACT   - Extract specific information from text
--   • AI_SENTIMENT - Score sentiment from -1 (negative) to +1 (positive)
--   • AI_TRANSLATE - Translate between languages
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- AI_TRANSLATE: Handle international communications FIRST
-- Translate non-English emails before analysis
-- =============================================================================

-- View our non-English emails
SELECT email_id, original_language, subject, email_content
FROM compliance_emails
WHERE original_language != 'en';

-- Translate German email to English
SELECT 
    email_id,
    original_language,
    subject,
    AI_TRANSLATE(email_content, 'de', 'en') AS translated_content
FROM compliance_emails
WHERE original_language = 'de';

-- Translate French email to English
SELECT 
    email_id,
    original_language,
    subject,
    AI_TRANSLATE(email_content, 'fr', 'en') AS translated_content
FROM compliance_emails
WHERE original_language = 'fr';

-- Translate ALL non-English emails and analyze
SELECT 
    email_id,
    original_language,
    subject,
    
    -- Translate to English
    CASE 
        WHEN original_language = 'en' THEN email_content
        ELSE AI_TRANSLATE(email_content, original_language, 'en')
    END AS english_content,
    
    -- Now classify the translated content
    AI_CLASSIFY(
        CASE 
            WHEN original_language = 'en' THEN email_content
            ELSE AI_TRANSLATE(email_content, original_language, 'en')
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS risk_category
    
FROM compliance_emails;

-- =============================================================================
-- AI_EXTRACT: Pull specific information from text
-- Ask targeted questions to extract structured data
-- =============================================================================

-- Example 1: Extract securities/tickers mentioned
SELECT 
    email_id,
    subject,
    AI_EXTRACT(email_content, 'What stock tickers or securities are mentioned?') AS securities
FROM compliance_emails;

-- Example 2: Extract multiple pieces of information
SELECT 
    email_id,
    sender,
    subject,
    AI_EXTRACT(email_content, 'What companies or organizations are mentioned?') AS companies,
    AI_EXTRACT(email_content, 'What dates or timeframes are referenced?') AS dates,
    AI_EXTRACT(email_content, 'What specific actions are being suggested?') AS suggested_actions
FROM compliance_emails
WHERE compliance_flag = TRUE;

-- Example 3: Extract from translated content
SELECT 
    email_id,
    original_language,
    AI_EXTRACT(
        CASE 
            WHEN original_language = 'en' THEN email_content
            ELSE AI_TRANSLATE(email_content, original_language, 'en')
        END,
        'What confidential information is being shared?'
    ) AS confidential_info
FROM compliance_emails
WHERE compliance_flag = TRUE;

-- =============================================================================
-- AI_SENTIMENT: Analyze emotional tone
-- Returns score from -1 (very negative) to +1 (very positive)
-- =============================================================================

-- Example 1: Score sentiment of all emails
SELECT 
    email_id,
    sender,
    subject,
    AI_SENTIMENT(email_content) AS sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(email_content) < -0.5 THEN '🔴 Very Negative'
        WHEN AI_SENTIMENT(email_content) < -0.2 THEN '🟠 Negative'
        WHEN AI_SENTIMENT(email_content) < 0.2 THEN '🟡 Neutral'
        WHEN AI_SENTIMENT(email_content) < 0.5 THEN '🟢 Positive'
        ELSE '🟢 Very Positive'
    END AS sentiment_label
FROM compliance_emails
ORDER BY sentiment_score ASC;

-- Example 2: Flag emails with concerning sentiment patterns
SELECT 
    email_id,
    trader_id,
    subject,
    AI_SENTIMENT(email_content) AS sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(email_content) < -0.3 THEN 'REVIEW - Negative tone'
        WHEN AI_SENTIMENT(email_content) > 0.7 THEN 'REVIEW - Unusually positive'
        ELSE 'Normal'
    END AS sentiment_flag
FROM compliance_emails
WHERE trader_id IS NOT NULL;

-- =============================================================================
-- COMBINED: Full extraction pipeline with translation
-- =============================================================================

SELECT 
    email_id,
    sender,
    original_language,
    
    -- Translate if needed
    CASE 
        WHEN original_language = 'en' THEN email_content
        ELSE AI_TRANSLATE(email_content, original_language, 'en')
    END AS english_content,
    
    -- Sentiment analysis
    AI_SENTIMENT(
        CASE 
            WHEN original_language = 'en' THEN email_content
            ELSE AI_TRANSLATE(email_content, original_language, 'en')
        END
    ) AS sentiment_score,
    
    -- Key extractions
    AI_EXTRACT(
        CASE 
            WHEN original_language = 'en' THEN email_content
            ELSE AI_TRANSLATE(email_content, original_language, 'en')
        END,
        'What securities or financial instruments are mentioned?'
    ) AS securities_mentioned,
    
    AI_EXTRACT(
        CASE 
            WHEN original_language = 'en' THEN email_content
            ELSE AI_TRANSLATE(email_content, original_language, 'en')
        END,
        'What is the main action being requested or suggested?'
    ) AS requested_action

FROM compliance_emails
WHERE compliance_flag = TRUE;

-- =============================================================================
-- TRY IT YOURSELF
-- =============================================================================

-- Your turn: Extract different information
SELECT 
    email_id,
    subject,
    AI_EXTRACT(email_content, 'YOUR EXTRACTION QUESTION HERE') AS your_extraction
FROM compliance_emails;

