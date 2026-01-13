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
-- STEP 1: DETECT LANGUAGE
-- First, we need to identify which emails are not in English
-- Use CORTEX.COMPLETE to detect language and update the lang column
-- =============================================================================

-- Detect language for each email and update the lang column
UPDATE compliance_emails
SET lang = TRIM(SNOWFLAKE.CORTEX.COMPLETE(
    'claude-sonnet-4-5',
    'What language is this text written in? Reply with ONLY the 2-letter ISO language code (en, de, fr, es, etc). No other text.

Text: ' || LEFT(email_content, 200)
));

-- Verify language detection
SELECT email_id, sender, subject, lang, LEFT(email_content, 50) || '...' AS preview
FROM compliance_emails
ORDER BY email_id;

-- =============================================================================
-- STEP 2: AI_TRANSLATE
-- Now use the lang column to identify and translate non-English emails
-- =============================================================================

-- View non-English emails (using the detected lang column)
SELECT email_id, lang, sender, subject, LEFT(email_content, 80) || '...' AS preview
FROM compliance_emails
WHERE lang != 'en';

-- Translate non-English emails to English
SELECT 
    email_id,
    lang,
    sender,
    subject,
    lang || ' → en' AS translation,
    AI_TRANSLATE(email_content, lang, 'en') AS english_content
FROM compliance_emails
WHERE lang != 'en';

-- =============================================================================
-- STEP 3: AI_SENTIMENT
-- Score emotional tone: -1 (negative) to +1 (positive)
-- Unusual sentiment can indicate stress, urgency, or deception
-- =============================================================================

-- Analyze sentiment across all emails (translate first if needed)
SELECT 
    email_id,
    sender,
    subject,
    lang,
    ROUND(AI_SENTIMENT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END
    ), 2) AS sentiment_score,
    CASE 
        WHEN AI_SENTIMENT(
            CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END
        ) < -0.3 THEN '🔴 Negative - Review'
        WHEN AI_SENTIMENT(
            CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END
        ) > 0.5 THEN '🟢 Positive'
        ELSE '🟡 Neutral'
    END AS tone
FROM compliance_emails
ORDER BY sentiment_score;

-- =============================================================================
-- STEP 4: AI_CLASSIFY
-- Categorize emails into violation types
-- Zero-shot: define categories, get predictions immediately
-- =============================================================================

-- Classify all emails (with translation for non-English)
SELECT 
    email_id,
    sender,
    subject,
    lang,
    AI_CLASSIFY(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ) AS classification
FROM compliance_emails;

-- Extract just class and confidence
SELECT 
    email_id,
    subject,
    lang,
    AI_CLASSIFY(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS violation_type,
    ROUND(AI_CLASSIFY(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):confidence::FLOAT, 2) AS confidence
FROM compliance_emails
ORDER BY confidence DESC;

-- =============================================================================
-- STEP 5: AI_EXTRACT
-- Pull out SPECIFIC phrases that are compliance violations
-- This is key evidence for investigations
-- =============================================================================

-- Extract the problematic phrases
SELECT 
    email_id,
    subject,
    lang,
    AI_EXTRACT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        'What specific phrases indicate a compliance violation or policy breach?'
    ) AS violating_phrases
FROM compliance_emails
WHERE AI_CLASSIFY(
    CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END,
    ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
):class::STRING != 'clean';

-- Extract more specific information
SELECT 
    email_id,
    subject,
    AI_EXTRACT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        'What securities, companies, or financial instruments are mentioned?'
    ) AS securities_mentioned,
    AI_EXTRACT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        'What instructions to hide, delete, or keep secret are given?'
    ) AS concealment_instructions
FROM compliance_emails
WHERE lang != 'en' OR has_attachment = TRUE;  -- Focus on suspicious emails

-- =============================================================================
-- STEP 6: PUT THEM ALL TOGETHER
-- Combined analysis using all functions
-- =============================================================================

SELECT 
    email_id,
    sender,
    subject,
    lang,
    
    -- Translated content (for reference)
    LEFT(CASE 
        WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
        ELSE email_content
    END, 100) || '...' AS content_preview,
    
    -- Sentiment
    ROUND(AI_SENTIMENT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END
    ), 2) AS sentiment,
    
    -- Classification
    AI_CLASSIFY(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS violation_type,
    
    -- Key evidence
    AI_EXTRACT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        'What is the single most concerning phrase in this email?'
    ) AS key_evidence

FROM compliance_emails
ORDER BY 
    CASE AI_CLASSIFY(
        CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END,
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

1. CORTEX.COMPLETE - Detect language (stored in lang column)
2. AI_TRANSLATE    - Translate non-English emails using the lang column
3. AI_SENTIMENT    - Flag unusual emotional tones  
4. AI_CLASSIFY     - Categorize violation types
5. AI_EXTRACT      - Pull specific violating phrases as evidence

The lang column lets us dynamically handle any language without hardcoding!

These are FINE-TUNED models optimized for each specific task.
They're fast and convenient.

Next: See the full AISQL pipeline → 02_aisql_approach.sql
Then: Compare with CORTEX.COMPLETE + Frontier models → 03_complete_approach.sql
*/
