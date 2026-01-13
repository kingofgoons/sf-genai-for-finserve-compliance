-- =============================================================================
-- 02_AISQL_APPROACH.SQL
-- Full Compliance Pipeline Using Stored AI Analysis
-- 
-- PREREQUISITE: Run 01_building_blocks.sql first to populate analysis columns!
-- This worksheet queries the pre-computed AI results for fast analysis.
-- =============================================================================

USE ROLE GENAI_COMPLIANCE_ROLE;
USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- VERIFY ANALYSIS IS COMPLETE
-- =============================================================================

SELECT 
    COUNT(*) AS total_emails,
    COUNT(lang) AS lang_detected,
    COUNT(en_content) AS translated,
    COUNT(sentiment) AS sentiment_analyzed,
    COUNT(classification) AS classified,
    COUNT(compliance_flag) AS flagged
FROM compliance_emails;

-- =============================================================================
-- EMAIL ANALYSIS VIEW (using stored columns)
-- =============================================================================

CREATE OR REPLACE VIEW aisql_email_analysis AS
SELECT 
    e.email_id,
    e.sender,
    e.recipient,
    e.subject,
    e.lang,
    e.has_attachment,
    e.en_content,
    
    -- Sentiment from stored analysis
    e.sentiment:categories[0]:sentiment::STRING AS overall_tone,
    e.sentiment:categories[1]:sentiment::STRING AS confidentiality,
    e.sentiment:categories[3]:sentiment::STRING AS deletion,
    e.sentiment:categories[4]:sentiment::STRING AS risk,
    
    -- Classification from stored analysis
    e.violations_list,
    ARRAY_SIZE(e.classification:labels) AS violation_count,
    
    -- Extracted evidence
    e.extracted_info,
    
    -- Derived fields
    e.compliance_flag,
    CASE 
        WHEN e.compliance_flag = 'CRITICAL' THEN '🚨 ESCALATE IMMEDIATELY'
        WHEN e.compliance_flag = 'SENSITIVE' THEN '⚠️ COMPLIANCE REVIEW'
        WHEN e.compliance_flag = 'MONITOR' THEN '👀 MONITOR'
        ELSE '✅ NO ACTION'
    END AS recommended_action

FROM compliance_emails e;

-- =============================================================================
-- VIEW RESULTS
-- =============================================================================

-- Summary dashboard
SELECT 
    email_id,
    sender,
    subject,
    compliance_flag,
    violations_list,
    overall_tone,
    recommended_action
FROM aisql_email_analysis
ORDER BY 
    CASE compliance_flag
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        WHEN 'MONITOR' THEN 3
        ELSE 4
    END;

-- Detailed view with evidence (violations only)
SELECT 
    email_id,
    subject,
    compliance_flag,
    violations_list,
    extracted_info
FROM aisql_email_analysis
WHERE violation_count > 0;

-- =============================================================================
-- ATTACHMENT ANALYSIS VIEW
-- =============================================================================

-- First, populate attachment analysis columns
UPDATE email_attachments
SET 
    classification = AI_CLASSIFY(
        image_description,
        [
            {'label': 'data_leak', 'description': 'sensitive data visible in image'},
            {'label': 'insider_info', 'description': 'non-public financial information'},
            {'label': 'unauthorized_sharing', 'description': 'internal-only or restricted content'},
            {'label': 'credential_exposure', 'description': 'passwords, IPs, or system access info'}
        ],
        {'task_description': 'Identify security concerns in document/image content', 'output_mode': 'multi'}
    ),
    extracted_info = AI_EXTRACT(
        image_description,
        ['sensitive data visible', 'confidential markings', 'internal identifiers']
    )
WHERE classification IS NULL;

-- Update violations list
UPDATE email_attachments
SET violations_list = ARRAY_TO_STRING(classification:labels, ', ')
WHERE violations_list IS NULL AND classification IS NOT NULL;

-- Update compliance flag
UPDATE email_attachments
SET compliance_flag = CASE 
    WHEN ARRAY_SIZE(classification:labels) > 0 THEN 'SENSITIVE'
    ELSE 'CLEAN'
END
WHERE compliance_flag IS NULL AND classification IS NOT NULL;

-- Create attachment view
CREATE OR REPLACE VIEW aisql_attachment_analysis AS
SELECT 
    a.attachment_id,
    a.email_id,
    a.filename,
    a.file_type,
    a.violations_list,
    a.extracted_info AS sensitive_elements,
    a.compliance_flag AS severity
FROM email_attachments a;

-- View attachment results
SELECT 
    attachment_id,
    email_id,
    filename,
    violations_list,
    severity,
    sensitive_elements
FROM aisql_attachment_analysis;

-- =============================================================================
-- COMBINED DASHBOARD: Emails + Attachments
-- =============================================================================

CREATE OR REPLACE VIEW aisql_combined_dashboard AS
SELECT 
    e.email_id,
    e.sender,
    e.subject,
    e.compliance_flag AS email_flag,
    e.violations_list AS email_violations,
    a.filename AS attachment,
    a.compliance_flag AS attachment_flag,
    a.violations_list AS attachment_violations,
    
    -- Overall severity (worst of email + attachment)
    CASE 
        WHEN e.compliance_flag = 'CRITICAL' OR a.compliance_flag = 'CRITICAL' THEN 'CRITICAL'
        WHEN e.compliance_flag = 'SENSITIVE' OR a.compliance_flag = 'SENSITIVE' THEN 'SENSITIVE'
        WHEN e.compliance_flag = 'MONITOR' THEN 'MONITOR'
        ELSE 'CLEAN'
    END AS overall_severity

FROM compliance_emails e
LEFT JOIN email_attachments a ON e.email_id = a.email_id;

-- View combined results
SELECT * FROM aisql_combined_dashboard
ORDER BY 
    CASE overall_severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        WHEN 'MONITOR' THEN 3
        ELSE 4
    END;

-- =============================================================================
-- QUICK COMPLIANCE QUERIES
-- =============================================================================

-- All CRITICAL items
SELECT email_id, sender, subject, email_violations, attachment, attachment_violations
FROM aisql_combined_dashboard
WHERE overall_severity = 'CRITICAL';

-- Emails with insider trading
SELECT email_id, sender, subject, email_violations
FROM aisql_combined_dashboard
WHERE email_violations LIKE '%insider_trading%';

-- Attachments with data leaks
SELECT email_id, attachment, attachment_violations
FROM aisql_combined_dashboard
WHERE attachment_violations LIKE '%data_leak%';

-- Summary by severity
SELECT 
    overall_severity,
    COUNT(*) AS count
FROM aisql_combined_dashboard
GROUP BY overall_severity
ORDER BY 
    CASE overall_severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        WHEN 'MONITOR' THEN 3
        ELSE 4
    END;

-- =============================================================================
-- KEY TAKEAWAYS
-- =============================================================================

/*
The AISQL Approach:
1. Run AI functions ONCE to populate analysis columns
2. Create views that query the stored results
3. Simple, fast queries without re-running AI

Benefits:
- Consistent results (no variation between queries)
- Fast queries (no AI latency)
- Lower costs (AI functions run once, not per query)
- Simpler SQL (just query columns, no complex function calls)

The fine-tuned AI SQL functions (AI_TRANSLATE, AI_SENTIMENT, AI_CLASSIFY, AI_EXTRACT)
are optimized for specific tasks and work great for batch processing.

Next: See CORTEX.COMPLETE with Frontier models → 03_complete_approach.sql
*/
