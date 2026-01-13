-- =============================================================================
-- 02_AISQL_APPROACH.SQL
-- Full Compliance Pipeline Using Fine-Tuned AI SQL Functions
-- 
-- This approach uses the purpose-built AI SQL functions.
-- Optimized for performance, convenient for common patterns.
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- CREATE THE AISQL PIPELINE
-- Uses: AI_TRANSLATE, AI_SENTIMENT, AI_CLASSIFY, AI_EXTRACT
-- =============================================================================

CREATE OR REPLACE VIEW aisql_email_analysis AS
SELECT 
    e.email_id,
    e.sender,
    e.recipient,
    e.subject,
    e.has_attachment,
    
    -- Step 1: Translate to English (using detected lang column)
    CASE 
        WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
        ELSE e.email_content
    END AS english_content,
    
    -- Step 2: Sentiment analysis (compliance-focused categories)
    -- Negative toward confidentiality = disregarding it = BAD
    -- Positive toward deletion/risk = encouraging bad behavior = BAD
    AI_SENTIMENT(
        CASE 
            WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
            ELSE e.email_content
        END,
        ['confidentiality', 'deletion', 'risk']
    ):categories[0]:sentiment::STRING AS overall_tone,
    AI_SENTIMENT(
        CASE 
            WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
            ELSE e.email_content
        END,
        ['confidentiality', 'deletion', 'risk']
    ):categories[1]:sentiment::STRING AS confidentiality_sentiment,
    
    -- Step 3: Classification
    -- Note: AI_CLASSIFY returns {"labels": ["category"]} - no confidence score
    AI_CLASSIFY(
        CASE 
            WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
            ELSE e.email_content
        END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):labels[0]::STRING AS violation_type,
    
    -- Step 4: Extract evidence
    AI_EXTRACT(
        CASE 
            WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
            ELSE e.email_content
        END,
        'What specific phrases indicate a policy violation?'
    ) AS violating_phrases,
    
    AI_EXTRACT(
        CASE 
            WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
            ELSE e.email_content
        END,
        'What securities or companies are mentioned?'
    ) AS securities_mentioned,
    
    -- Derived: Severity level
    CASE 
        WHEN AI_CLASSIFY(
            CASE 
                WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
                ELSE e.email_content
            END,
            ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
        ):labels[0]::STRING IN ('insider_trading', 'market_manipulation') THEN 'CRITICAL'
        WHEN AI_CLASSIFY(
            CASE 
                WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
                ELSE e.email_content
            END,
            ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
        ):labels[0]::STRING = 'data_exfiltration' THEN 'SENSITIVE'
        ELSE 'CLEAN'
    END AS severity,
    
    -- Derived: Recommended action
    CASE 
        WHEN AI_CLASSIFY(
            CASE 
                WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
                ELSE e.email_content
            END,
            ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
        ):labels[0]::STRING != 'clean' THEN '🚨 ESCALATE'
        ELSE '✅ NO ACTION'
    END AS recommended_action

FROM compliance_emails e;

-- =============================================================================
-- VIEW RESULTS
-- =============================================================================

-- Summary view
SELECT 
    email_id,
    sender,
    subject,
    violation_type,
    severity,
    overall_tone,
    recommended_action
FROM aisql_email_analysis
ORDER BY 
    CASE severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        ELSE 3
    END;

-- Detailed view with evidence
SELECT 
    email_id,
    subject,
    violation_type,
    severity,
    violating_phrases,
    securities_mentioned
FROM aisql_email_analysis
WHERE violation_type != 'clean';

-- =============================================================================
-- ATTACHMENT ANALYSIS (Using AI_CLASSIFY + AI_EXTRACT)
-- =============================================================================

CREATE OR REPLACE VIEW aisql_attachment_analysis AS
SELECT 
    a.attachment_id,
    a.email_id,
    a.filename,
    a.file_type,
    
    -- Classify attachment content
    -- Note: AI_CLASSIFY returns {"labels": ["category"]} - no confidence score
    AI_CLASSIFY(
        a.image_description,
        ['data_leak', 'insider_info', 'unauthorized_sharing', 'clean']
    ):labels[0]::STRING AS violation_type,
    
    -- Extract sensitive elements
    AI_EXTRACT(
        a.image_description,
        'What sensitive or confidential information is visible?'
    ) AS sensitive_elements,
    
    -- Severity
    CASE 
        WHEN AI_CLASSIFY(a.image_description,
            ['data_leak', 'insider_info', 'unauthorized_sharing', 'clean']
        ):labels[0]::STRING != 'clean' THEN 'SENSITIVE'
        ELSE 'CLEAN'
    END AS severity

FROM email_attachments a;

-- View attachment results
SELECT 
    attachment_id,
    email_id,
    filename,
    violation_type,
    severity,
    sensitive_elements
FROM aisql_attachment_analysis;

-- =============================================================================
-- COMBINED DASHBOARD
-- =============================================================================

SELECT 
    e.email_id,
    e.sender,
    e.subject,
    e.violation_type AS email_violation,
    e.severity AS email_severity,
    a.filename AS attachment,
    a.violation_type AS attachment_violation,
    a.severity AS attachment_severity,
    
    -- Overall severity (worst of either)
    CASE 
        WHEN e.severity = 'CRITICAL' OR a.severity = 'CRITICAL' THEN 'CRITICAL'
        WHEN e.severity = 'SENSITIVE' OR a.severity = 'SENSITIVE' THEN 'SENSITIVE'
        ELSE 'CLEAN'
    END AS overall_severity,
    
    e.recommended_action
    
FROM aisql_email_analysis e
LEFT JOIN aisql_attachment_analysis a ON e.email_id = a.email_id
ORDER BY 
    CASE 
        WHEN e.severity = 'CRITICAL' OR a.severity = 'CRITICAL' THEN 1
        WHEN e.severity = 'SENSITIVE' OR a.severity = 'SENSITIVE' THEN 2
        ELSE 3
    END;

-- =============================================================================
-- AISQL APPROACH SUMMARY
-- =============================================================================

/*
PROS of AI SQL Functions:
✅ Purpose-built, optimized for specific tasks
✅ Simple syntax - just function calls
✅ Fast execution
✅ Consistent output format

CONS:
❌ Less control over output schema
❌ Limited to predefined function behaviors
❌ Can't customize prompts deeply
❌ Uses fine-tuned models, not latest Frontier models

Next: See same pipeline with CORTEX.COMPLETE → 03_complete_approach.sql
*/

