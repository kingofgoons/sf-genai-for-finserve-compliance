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
-- Analyze sentiment toward compliance-relevant TOPICS
-- Returns: positive, negative, neutral, mixed, unknown for each category
-- 
-- Key insight: A friendly email can still violate compliance!
-- Simple single-word categories work better with sentiment models:
--   - confidentiality: how the email treats confidential info
--   - timing: urgency, deadlines, "act now"
--   - deletion: destroying/removing records
--   - risk: dangerous, forbidden activities
-- =============================================================================

-- First, see the raw sentiment analysis
SELECT 
    email_id,
    sender,
    subject,
    lang,
    AI_SENTIMENT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['confidentiality', 'timing', 'deletion', 'risk']
    ) AS sentiment_analysis
FROM compliance_emails;

-- Extract and flag concerning patterns
-- NEGATIVE toward confidentiality = disregarding it = BAD
-- POSITIVE toward deletion = encouraging it = BAD
-- POSITIVE toward risk = encouraging risky behavior = BAD
SELECT 
    email_id,
    subject,
    sentiment:categories[0]:sentiment::STRING AS overall_tone,
    sentiment:categories[1]:sentiment::STRING AS confidentiality,
    sentiment:categories[2]:sentiment::STRING AS timing,
    sentiment:categories[3]:sentiment::STRING AS deletion,
    sentiment:categories[4]:sentiment::STRING AS risk,
    -- Flag logic
    CASE 
        WHEN sentiment:categories[4]:sentiment::STRING IN ('positive', 'mixed')  -- positive toward risk
        THEN '🔴 CRITICAL - Risky Behavior Encouraged'
        WHEN sentiment:categories[3]:sentiment::STRING IN ('positive', 'mixed')  -- positive toward deletion
        THEN '🔴 CRITICAL - Evidence Destruction'
        WHEN sentiment:categories[1]:sentiment::STRING IN ('negative', 'mixed')  -- negative toward confidentiality
        THEN '🟠 HIGH - Confidentiality Breach'
        WHEN sentiment:categories[2]:sentiment::STRING IN ('positive', 'mixed')  -- urgent timing
          AND sentiment:categories[0]:sentiment::STRING = 'negative'             -- with negative overall tone
        THEN '🟡 REVIEW - Urgent & Negative'
        ELSE '🟢 Clean'
    END AS compliance_flag
FROM (
    SELECT 
        email_id,
        subject,
        AI_SENTIMENT(
            CASE 
                WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
                ELSE email_content
            END,
            ['confidentiality', 'timing', 'deletion', 'risk']
        ) AS sentiment
    FROM compliance_emails
)
ORDER BY 
    CASE compliance_flag
        WHEN '🔴 CRITICAL - Risky Behavior Encouraged' THEN 1
        WHEN '🔴 CRITICAL - Evidence Destruction' THEN 2
        WHEN '🟠 HIGH - Confidentiality Breach' THEN 3
        WHEN '🟡 REVIEW - Urgent & Negative' THEN 4
        ELSE 5
    END;

-- =============================================================================
-- STEP 4: AI_CLASSIFY
-- Categorize emails into violation types
-- Using multi-label mode with task description for better accuracy
-- Categories are actual violation types (no "clean" - absence of violations = clean)
-- =============================================================================

-- Classify all emails with multi-label support and task context
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
        [
            {'label': 'insider_trading', 'description': 'sharing non-public information for trading advantage'},
            {'label': 'market_manipulation', 'description': 'coordinating trades to artificially move prices'},
            {'label': 'data_exfiltration', 'description': 'sharing confidential company data externally'},
            {'label': 'policy_violation', 'description': 'instructions to delete evidence or hide communications'}
        ],
        {
            'task_description': 'Identify compliance violations in financial services communications',
            'output_mode': 'multi'
        }
    ) AS classification
FROM compliance_emails;

-- Extract labels with severity assessment
-- Empty labels array = no violations detected = clean
SELECT 
    email_id,
    subject,
    lang,
    AI_CLASSIFY(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        [
            {'label': 'insider_trading', 'description': 'sharing non-public information for trading advantage'},
            {'label': 'market_manipulation', 'description': 'coordinating trades to artificially move prices'},
            {'label': 'data_exfiltration', 'description': 'sharing confidential company data externally'},
            {'label': 'policy_violation', 'description': 'instructions to delete evidence or hide communications'}
        ],
        {'task_description': 'Identify compliance violations in financial services communications', 'output_mode': 'multi'}
    ):labels AS violation_labels,
    CASE 
        WHEN ARRAY_SIZE(AI_CLASSIFY(
            CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END,
            [
                {'label': 'insider_trading', 'description': 'sharing non-public information for trading advantage'},
                {'label': 'market_manipulation', 'description': 'coordinating trades to artificially move prices'},
                {'label': 'data_exfiltration', 'description': 'sharing confidential company data externally'},
                {'label': 'policy_violation', 'description': 'instructions to delete evidence or hide communications'}
            ],
            {'task_description': 'Identify compliance violations in financial services communications', 'output_mode': 'multi'}
        ):labels) = 0 THEN '🟢 CLEAN'
        ELSE '🔴 VIOLATIONS DETECTED'
    END AS status
FROM compliance_emails
ORDER BY 
    ARRAY_SIZE(AI_CLASSIFY(
        CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END,
        [
            {'label': 'insider_trading', 'description': 'sharing non-public information for trading advantage'},
            {'label': 'market_manipulation', 'description': 'coordinating trades to artificially move prices'},
            {'label': 'data_exfiltration', 'description': 'sharing confidential company data externally'},
            {'label': 'policy_violation', 'description': 'instructions to delete evidence or hide communications'}
        ],
        {'task_description': 'Identify compliance violations in financial services communications', 'output_mode': 'multi'}
    ):labels) DESC;

-- =============================================================================
-- STEP 5: AI_EXTRACT
-- Pull out SPECIFIC entities and information from emails
-- AI_EXTRACT now takes an array of items to extract
-- =============================================================================

-- Extract compliance-relevant entities
SELECT 
    email_id,
    subject,
    lang,
    AI_EXTRACT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['violating phrases', 'securities mentioned', 'people involved', 'dates and times']
    ) AS extracted_info
FROM compliance_emails
WHERE ARRAY_SIZE(AI_CLASSIFY(
    CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END,
    [
        {'label': 'insider_trading', 'description': 'sharing non-public information for trading advantage'},
        {'label': 'market_manipulation', 'description': 'coordinating trades to artificially move prices'},
        {'label': 'data_exfiltration', 'description': 'sharing confidential company data externally'},
        {'label': 'policy_violation', 'description': 'instructions to delete evidence or hide communications'}
    ],
    {'task_description': 'Identify compliance violations in financial services communications', 'output_mode': 'multi'}
):labels) > 0;  -- Has at least one violation

-- Extract with more specific categories
SELECT 
    email_id,
    subject,
    AI_EXTRACT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['stock tickers', 'company names', 'dollar amounts', 'instructions to delete']
    ) AS key_entities
FROM compliance_emails
WHERE lang != 'en' OR has_attachment = TRUE;

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
    
    -- Sentiment toward compliance-relevant topics
    AI_SENTIMENT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['confidentiality', 'deletion', 'risk']
    ):categories[0]:sentiment::STRING AS overall_tone,
    
    -- Classification (multi-label: could have multiple violations)
    -- Empty array = no violations = clean
    ARRAY_TO_STRING(
        AI_CLASSIFY(
            CASE 
                WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
                ELSE email_content
            END,
            [
                {'label': 'insider_trading', 'description': 'sharing non-public information'},
                {'label': 'market_manipulation', 'description': 'coordinating trades'},
                {'label': 'data_exfiltration', 'description': 'sharing confidential data externally'},
                {'label': 'policy_violation', 'description': 'deleting evidence or hiding communications'}
            ],
            {'task_description': 'Identify compliance violations', 'output_mode': 'multi'}
        ):labels, ', '
    ) AS violations,
    
    -- Key evidence
    AI_EXTRACT(
        CASE 
            WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
            ELSE email_content
        END,
        ['key violation phrase', 'recommended action']
    ) AS key_evidence

FROM compliance_emails
ORDER BY 
    ARRAY_SIZE(AI_CLASSIFY(
        CASE WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en') ELSE email_content END,
        [
            {'label': 'insider_trading', 'description': 'sharing non-public information'},
            {'label': 'market_manipulation', 'description': 'coordinating trades'},
            {'label': 'data_exfiltration', 'description': 'sharing confidential data externally'},
            {'label': 'policy_violation', 'description': 'deleting evidence or hiding communications'}
        ],
        {'task_description': 'Identify compliance violations', 'output_mode': 'multi'}
    ):labels) DESC;  -- Most violations first, clean (0) last

-- =============================================================================
-- KEY TAKEAWAYS
-- =============================================================================

/*
We've learned the building blocks:

1. CORTEX.COMPLETE - Detect language (stored in lang column)
2. AI_TRANSLATE    - Translate non-English emails using the lang column
3. AI_SENTIMENT    - Analyze sentiment toward compliance TOPICS:
                     - confidentiality (NEGATIVE = disregarding = BAD)
                     - deletion (POSITIVE = encouraging destruction = BAD)
                     - risk (POSITIVE = encouraging risky behavior = BAD)
                     Works even on friendly-toned emails with violations!
4. AI_CLASSIFY     - Categorize violation types
5. AI_EXTRACT      - Pull specific violating phrases as evidence

The lang column lets us dynamically handle any language without hardcoding!

These are FINE-TUNED models optimized for each specific task.
They're fast and convenient.

Next: See the full AISQL pipeline → 02_aisql_approach.sql
Then: Compare with CORTEX.COMPLETE + Frontier models → 03_complete_approach.sql
*/
