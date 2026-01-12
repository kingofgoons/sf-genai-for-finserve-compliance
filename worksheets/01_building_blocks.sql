-- =============================================================================
-- 01_BUILDING_BLOCKS.SQL
-- Learn Each AI SQL Function Progressively
-- 
-- Flow: AI_TRANSLATE → AI_SENTIMENT → AI_CLASSIFY → AI_EXTRACT → Combined
-- These are the fine-tuned AI SQL functions optimized for specific tasks.
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- STEP 1: AI_TRANSLATE
-- Start here - we have international communications to analyze
-- =============================================================================

-- First, see our non-English emails
SELECT email_id, sender, subject, LEFT(email_content, 80) || '...' AS preview
FROM compliance_emails
WHERE email_id IN (1, 5);

-- Translate German email to English
SELECT 
    email_id,
    sender,
    subject,
    'German → English' AS translation,
    AI_TRANSLATE(email_content, 'de', 'en') AS english_content
FROM compliance_emails
WHERE email_id = 1;

-- Translate French email to English
SELECT 
    email_id,
    sender,
    subject,
    'French → English' AS translation,
    AI_TRANSLATE(email_content, 'fr', 'en') AS english_content
FROM compliance_emails
WHERE email_id = 5;

-- Now we can analyze all emails in English!

-- =============================================================================
-- STEP 2: AI_SENTIMENT
-- Score emotional tone: -1 (negative) to +1 (positive)
-- Unusual sentiment can indicate stress, urgency, or deception
-- =============================================================================

-- Analyze sentiment across all emails (translate first if needed)
SELECT 
    email_id,
    sender,
    subject,
    ROUND(AI_SENTIMENT(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END
    ), 2) AS sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content END) < -0.3 THEN '🔴 Negative - Review'
        WHEN AI_SENTIMENT(CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content END) > 0.5 THEN '🟢 Positive'
        ELSE '🟡 Neutral'
    END AS tone
FROM compliance_emails
ORDER BY sentiment_score;

-- Notice: Email 4 (compliance training) is positive
-- Suspicious emails tend to have mixed or urgent tones

-- =============================================================================
-- STEP 3: AI_CLASSIFY
-- Categorize emails into violation types
-- Zero-shot: define categories, get predictions immediately
-- =============================================================================

-- Classify all emails (with translation)
SELECT 
    email_id,
    sender,
    subject,
    AI_CLASSIFY(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ) AS classification
FROM compliance_emails;

-- Extract just class and confidence
SELECT 
    email_id,
    subject,
    AI_CLASSIFY(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS violation_type,
    ROUND(AI_CLASSIFY(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):confidence::FLOAT, 2) AS confidence
FROM compliance_emails
ORDER BY confidence DESC;

-- =============================================================================
-- STEP 4: AI_EXTRACT
-- Pull out SPECIFIC phrases that are compliance violations
-- This is key evidence for investigations
-- =============================================================================

-- Extract the problematic phrases
SELECT 
    email_id,
    subject,
    AI_EXTRACT(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        'What specific phrases indicate a compliance violation or policy breach?'
    ) AS violating_phrases
FROM compliance_emails
WHERE email_id != 4;  -- Skip the clean email

-- Extract more specific information
SELECT 
    email_id,
    subject,
    AI_EXTRACT(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        'What securities, companies, or financial instruments are mentioned?'
    ) AS securities_mentioned,
    AI_EXTRACT(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        'What instructions to hide, delete, or keep secret are given?'
    ) AS concealment_instructions
FROM compliance_emails
WHERE email_id IN (2, 3, 5);  -- Suspicious emails only

-- =============================================================================
-- STEP 5: PUT THEM ALL TOGETHER
-- Combined analysis using all four functions
-- =============================================================================

SELECT 
    email_id,
    sender,
    subject,
    
    -- Translated content (for reference)
    LEFT(CASE 
        WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
        WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
        ELSE email_content
    END, 100) || '...' AS content_preview,
    
    -- Sentiment
    ROUND(AI_SENTIMENT(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END
    ), 2) AS sentiment,
    
    -- Classification
    AI_CLASSIFY(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS violation_type,
    
    -- Key evidence
    AI_EXTRACT(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        'What is the single most concerning phrase in this email?'
    ) AS key_evidence

FROM compliance_emails
ORDER BY 
    CASE AI_CLASSIFY(
        CASE 
            WHEN email_id = 1 THEN AI_TRANSLATE(email_content, 'de', 'en')
            WHEN email_id = 5 THEN AI_TRANSLATE(email_content, 'fr', 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING
        WHEN 'clean' THEN 4
        ELSE 1
    END;

-- =============================================================================
-- KEY TAKEAWAYS
-- =============================================================================

/*
We've learned the building blocks:

1. AI_TRANSLATE - Handle international communications
2. AI_SENTIMENT - Flag unusual emotional tones  
3. AI_CLASSIFY  - Categorize violation types
4. AI_EXTRACT   - Pull specific violating phrases as evidence

These are FINE-TUNED models optimized for each specific task.
They're fast and convenient.

Next: See the full AISQL pipeline → 02_aisql_approach.sql
Then: Compare with CORTEX.COMPLETE + Frontier models → 03_complete_approach.sql
*/

