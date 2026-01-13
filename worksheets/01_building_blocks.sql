-- =============================================================================
-- 01_BUILDING_BLOCKS.SQL
-- Learn Each AI SQL Function Progressively
-- 
-- This worksheet populates the analysis columns in compliance_emails table,
-- then demonstrates simple queries against the stored results.
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- STEP 1: DETECT LANGUAGE
-- Use CORTEX.COMPLETE to detect language and update the lang column
-- =============================================================================

UPDATE compliance_emails
SET lang = TRIM(SNOWFLAKE.CORTEX.COMPLETE(
    'claude-sonnet-4-5',
    'What language is this text written in? Reply with ONLY the 2-letter ISO language code (en, de, fr, es, etc). No other text.

Text: ' || LEFT(email_content, 200)
))
WHERE lang IS NULL;

-- Verify language detection
SELECT email_id, sender, subject, lang 
FROM compliance_emails;

-- =============================================================================
-- STEP 2: TRANSLATE TO ENGLISH
-- Use AI_TRANSLATE to populate en_content column
-- =============================================================================

UPDATE compliance_emails
SET en_content = CASE 
    WHEN lang != 'en' THEN AI_TRANSLATE(email_content, lang, 'en')
    ELSE email_content
END
WHERE en_content IS NULL;

-- Verify translations
SELECT email_id, lang, subject, LEFT(en_content, 100) || '...' AS english_preview
FROM compliance_emails;

-- =============================================================================
-- STEP 3: SENTIMENT ANALYSIS
-- Use AI_SENTIMENT with compliance-relevant categories
-- Store the full result for later querying
-- =============================================================================

UPDATE compliance_emails
SET sentiment = AI_SENTIMENT(
    en_content,
    ['confidentiality', 'timing', 'deletion', 'risk']
);

-- View sentiment results
SELECT 
    email_id, 
    subject,
    sentiment:categories[0]:sentiment::STRING AS overall_tone,
    sentiment:categories[1]:sentiment::STRING AS confidentiality,
    sentiment:categories[2]:sentiment::STRING AS timing,
    sentiment:categories[3]:sentiment::STRING AS deletion,
    sentiment:categories[4]:sentiment::STRING AS risk
FROM compliance_emails;

-- =============================================================================
-- STEP 4: CLASSIFICATION
-- Use AI_CLASSIFY with violation types and descriptions
-- =============================================================================

UPDATE compliance_emails
SET classification = AI_CLASSIFY(
    en_content,
    [
        {'label': 'insider_trading', 'description': 'sharing non-public information for trading advantage'},
        {'label': 'market_manipulation', 'description': 'coordinating trades to artificially move prices'},
        {'label': 'data_exfiltration', 'description': 'sharing confidential company data externally'},
        {'label': 'policy_violation', 'description': 'instructions to delete evidence or hide communications'}
    ],
    {'task_description': 'Identify compliance violations in financial services communications', 'output_mode': 'multi'}
);

-- Update violations_list for easy display
UPDATE compliance_emails
SET violations_list = ARRAY_TO_STRING(classification:labels, ', ');

-- View classification results
SELECT 
    email_id, 
    subject,
    violations_list,
    ARRAY_SIZE(classification:labels) AS violation_count
FROM compliance_emails;

-- =============================================================================
-- STEP 5: EXTRACT EVIDENCE
-- Use AI_EXTRACT to pull out specific entities
-- =============================================================================

UPDATE compliance_emails
SET extracted_info = AI_EXTRACT(
    en_content,
    ['violating phrases', 'securities mentioned', 'people involved', 'instructions to delete']
);

-- View extracted evidence
SELECT 
    email_id,
    subject,
    extracted_info
FROM compliance_emails
WHERE ARRAY_SIZE(classification:labels) > 0;

-- =============================================================================
-- STEP 6: DERIVE COMPLIANCE FLAGS
-- Set compliance_flag based on classification and sentiment
-- =============================================================================

UPDATE compliance_emails
SET compliance_flag = CASE 
    -- Critical: insider trading or market manipulation
    WHEN ARRAYS_OVERLAP(
        classification:labels,
        ARRAY_CONSTRUCT('insider_trading', 'market_manipulation')
    ) THEN 'CRITICAL'
    -- Sensitive: data exfiltration or policy violations
    WHEN ARRAY_SIZE(classification:labels) > 0 THEN 'SENSITIVE'
    -- Monitor: negative sentiment toward confidentiality or positive toward deletion/risk
    WHEN sentiment:categories[1]:sentiment::STRING IN ('negative', 'mixed')
      OR sentiment:categories[3]:sentiment::STRING IN ('positive', 'mixed')
      OR sentiment:categories[4]:sentiment::STRING IN ('positive', 'mixed')
    THEN 'MONITOR'
    -- Clean
    ELSE 'CLEAN'
END;

-- =============================================================================
-- NOW: SIMPLE QUERIES AGAINST STORED ANALYSIS
-- No more complex AI function calls - just query the columns!
-- =============================================================================

-- Summary dashboard
SELECT 
    email_id,
    sender,
    subject,
    lang,
    compliance_flag,
    violations_list,
    sentiment:categories[0]:sentiment::STRING AS tone
FROM compliance_emails
ORDER BY 
    CASE compliance_flag
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        WHEN 'MONITOR' THEN 3
        ELSE 4
    END;

-- Find all CRITICAL emails
SELECT email_id, sender, subject, violations_list, extracted_info
FROM compliance_emails
WHERE compliance_flag = 'CRITICAL';

-- Find emails with multiple violations
SELECT email_id, subject, violations_list, ARRAY_SIZE(classification:labels) AS count
FROM compliance_emails
WHERE ARRAY_SIZE(classification:labels) > 1;

-- Find emails flagged for insider trading
SELECT email_id, sender, subject, en_content
FROM compliance_emails
WHERE ARRAY_CONTAINS('insider_trading'::VARIANT, classification:labels);

-- Emails with negative confidentiality sentiment (even if clean classification)
SELECT email_id, subject, compliance_flag,
       sentiment:categories[1]:sentiment::STRING AS confidentiality_sentiment
FROM compliance_emails
WHERE sentiment:categories[1]:sentiment::STRING IN ('negative', 'mixed');

-- Full analysis for a specific email
SELECT 
    email_id,
    sender,
    recipient,
    subject,
    lang,
    en_content,
    compliance_flag,
    violations_list,
    sentiment,
    extracted_info
FROM compliance_emails
WHERE email_id = 2;

-- =============================================================================
-- KEY TAKEAWAYS
-- =============================================================================

/*
We've learned the building blocks:

1. CORTEX.COMPLETE - Detect language (stored in lang column)
2. AI_TRANSLATE    - Translate to English (stored in en_content)
3. AI_SENTIMENT    - Sentiment analysis (stored in sentiment VARIANT)
4. AI_CLASSIFY     - Violation classification (stored in classification VARIANT)
5. AI_EXTRACT      - Evidence extraction (stored in extracted_info VARIANT)

By storing results in columns:
- Run AI functions ONCE during data ingestion
- Query results instantly without re-running AI
- Simple WHERE clauses instead of complex function calls
- Consistent results across queries

Next: See the full AISQL pipeline → 02_aisql_approach.sql
Then: Compare with CORTEX.COMPLETE + Frontier models → 03_complete_approach.sql
*/
