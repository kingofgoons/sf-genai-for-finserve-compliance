-- =============================================================================
-- 03_COMPLETE_APPROACH.SQL
-- Full Compliance Pipeline Using CORTEX.COMPLETE + Frontier Models
-- 
-- This approach uses raw CORTEX.COMPLETE with structured outputs.
-- Full control, custom schemas, access to Claude/Llama/Mistral.
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- FRONTIER MODELS AVAILABLE
-- =============================================================================

/*
You have access to the best models:
• claude-sonnet-4-5   - Anthropic's flagship, excellent reasoning + multimodal
• llama3.1-70b        - Meta's open model, fast and capable
• llama3.1-405b       - Meta's largest model
• mistral-large2      - Strong multilingual capabilities
• snowflake-arctic    - Snowflake's native model
*/

-- =============================================================================
-- CREATE THE COMPLETE PIPELINE
-- Single call per email with custom JSON schema
-- =============================================================================

CREATE OR REPLACE VIEW complete_email_analysis AS
SELECT 
    e.email_id,
    e.sender,
    e.recipient,
    e.subject,
    e.has_attachment,
    
    -- Translate if needed (using detected lang column)
    CASE 
        WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
        ELSE e.email_content
    END AS english_content,
    
    -- Full analysis in ONE call with structured output
    PARSE_JSON(
        SNOWFLAKE.CORTEX.COMPLETE(
            'claude-sonnet-4-5',
            'You are a senior financial services compliance officer. Analyze this email thoroughly.

Return ONLY a valid JSON object with this EXACT schema:
{
    "violation_type": "<insider_trading|market_manipulation|data_exfiltration|clean>",
    "severity": "<CRITICAL|SENSITIVE|POTENTIALLY_SENSITIVE|CLEAN>",
    "confidence": <number 0-100>,
    "sentiment": "<negative|neutral|positive>",
    "summary": "<15 word max summary of the concern>",
    "violating_phrases": ["<exact quote 1>", "<exact quote 2>"],
    "securities_mentioned": ["<ticker or company 1>", "<ticker or company 2>"],
    "concealment_attempts": "<any instructions to delete, hide, or keep secret>",
    "recommended_action": "<escalate_immediately|compliance_review|monitor|no_action>",
    "reasoning": "<brief explanation of your assessment>"
}

Severity definitions:
- CRITICAL: Clear insider trading or market manipulation, immediate escalation
- SENSITIVE: Confidential information shared inappropriately
- POTENTIALLY_SENSITIVE: Warrants review but may be legitimate
- CLEAN: Normal business communication

Email from: ' || e.sender || '
To: ' || e.recipient || '
Subject: ' || e.subject || '

Body:
' || CASE 
    WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
    ELSE e.email_content
END || '

Return ONLY the JSON object. No markdown, no explanation outside the JSON.'
        )
    ) AS analysis

FROM compliance_emails e;

-- =============================================================================
-- VIEW RESULTS
-- =============================================================================

-- Summary view
SELECT 
    email_id,
    sender,
    subject,
    analysis:violation_type::STRING AS violation_type,
    analysis:severity::STRING AS severity,
    analysis:confidence::NUMBER AS confidence,
    analysis:sentiment::STRING AS sentiment,
    analysis:summary::STRING AS summary,
    analysis:recommended_action::STRING AS action
FROM complete_email_analysis
ORDER BY 
    CASE analysis:severity::STRING
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        WHEN 'POTENTIALLY_SENSITIVE' THEN 3
        ELSE 4
    END;

-- Detailed evidence view
SELECT 
    email_id,
    subject,
    analysis:violation_type::STRING AS violation_type,
    analysis:violating_phrases AS violating_phrases,
    analysis:securities_mentioned AS securities,
    analysis:concealment_attempts::STRING AS concealment,
    analysis:reasoning::STRING AS reasoning
FROM complete_email_analysis
WHERE analysis:violation_type::STRING != 'clean';

-- =============================================================================
-- ATTACHMENT ANALYSIS WITH COMPLETE
-- More detailed than AISQL approach
-- =============================================================================

CREATE OR REPLACE VIEW complete_attachment_analysis AS
SELECT 
    a.attachment_id,
    a.email_id,
    a.filename,
    a.file_type,
    
    PARSE_JSON(
        SNOWFLAKE.CORTEX.COMPLETE(
            'claude-sonnet-4-5',
            'You are a data security analyst reviewing an email attachment.

Analyze this attachment description for security and compliance concerns.

Return ONLY a valid JSON object:
{
    "violation_type": "<data_leak|insider_info|credential_exposure|pii_exposure|unauthorized_sharing|clean>",
    "severity": "<CRITICAL|SENSITIVE|POTENTIALLY_SENSITIVE|CLEAN>",
    "confidence": <0-100>,
    "sensitive_elements": ["<specific item 1>", "<specific item 2>"],
    "risk_factors": ["<risk 1>", "<risk 2>"],
    "recommended_action": "<block|quarantine|review|allow>",
    "reasoning": "<brief explanation>"
}

Severity guide:
- CRITICAL: Credentials, internal IPs, or clear policy violation visible
- SENSITIVE: Confidential business info, PII, or internal-only documents
- POTENTIALLY_SENSITIVE: May contain info not meant for external sharing
- CLEAN: No security concerns

Attachment: ' || a.filename || ' (' || a.file_type || ')
Content description: ' || a.image_description || '

Return ONLY the JSON object.'
        )
    ) AS analysis

FROM email_attachments a;

-- View attachment results
SELECT 
    attachment_id,
    email_id,
    filename,
    analysis:violation_type::STRING AS violation_type,
    analysis:severity::STRING AS severity,
    analysis:confidence::NUMBER AS confidence,
    analysis:sensitive_elements AS sensitive_elements,
    analysis:recommended_action::STRING AS action,
    analysis:reasoning::STRING AS reasoning
FROM complete_attachment_analysis
ORDER BY analysis:confidence::NUMBER DESC;

-- =============================================================================
-- REAL IMAGE ANALYSIS (Using actual files from stage)
-- =============================================================================

/*
PREREQUISITE: Upload attachments to the stage before running these queries.

From SnowSQL or Snowsight file upload:
    PUT file:///path/to/assets/order_entry_screenshot.png @compliance_attachments/2024/12/;
    PUT file:///path/to/assets/AAPL_Analysis.png @compliance_attachments/2024/12/;
    PUT file:///path/to/assets/ACME.Finance.Trading.Infra.png @compliance_attachments/2024/12/;

Verify upload:
    LIST @compliance_attachments;
*/

-- Analyze trading system screenshot
SELECT 
    'order_entry_screenshot.png' AS filename,
    SNOWFLAKE.CORTEX.COMPLETE(
        'claude-sonnet-4-5',
        'You are a compliance analyst. Analyze this trading system screenshot.
        Look for: coordinated trading evidence, suspicious annotations, visible account numbers.
        
Return JSON: {"violation_type": "...", "severity": "CRITICAL|SENSITIVE|CLEAN", "concerns": [...], "action": "..."}',
        GET_PRESIGNED_URL(@compliance_attachments, '2024/12/order_entry_screenshot.png')
    ) AS analysis;

-- Analyze architecture diagram for data leak risk
SELECT 
    'ACME.Finance.Trading.Infra.png' AS filename,
    SNOWFLAKE.CORTEX.COMPLETE(
        'claude-sonnet-4-5',
        'Analyze this architecture diagram for security concerns.
        Look for: exposed IPs, server names, credentials, internal-only markings.
        
Return JSON: {"violation_type": "...", "severity": "...", "exposed_info": [...], "safe_for_external": true/false}',
        GET_PRESIGNED_URL(@compliance_attachments, '2024/12/ACME.Finance.Trading.Infra.png')
    ) AS analysis;

-- Analyze Excel screenshot for insider trading indicators
SELECT 
    'AAPL_Analysis.png' AS filename,
    SNOWFLAKE.CORTEX.COMPLETE(
        'claude-sonnet-4-5',
        'Analyze this spreadsheet screenshot for insider trading indicators.
        Look for: insider sources, non-public information, trade recommendations.
        
Return JSON: {"violation_type": "...", "severity": "...", "insider_indicators": [...], "securities": [...]}',
        GET_PRESIGNED_URL(@compliance_attachments, '2024/12/AAPL_Analysis.png')
    ) AS analysis;

-- =============================================================================
-- COMBINED DASHBOARD
-- =============================================================================

CREATE OR REPLACE VIEW complete_dashboard AS
SELECT 
    e.email_id,
    e.sender,
    e.subject,
    
    -- Email analysis
    e.analysis:violation_type::STRING AS email_violation,
    e.analysis:severity::STRING AS email_severity,
    e.analysis:confidence::NUMBER AS email_confidence,
    e.analysis:summary::STRING AS email_summary,
    e.analysis:violating_phrases AS evidence,
    
    -- Attachment analysis
    a.filename AS attachment,
    a.analysis:violation_type::STRING AS attachment_violation,
    a.analysis:severity::STRING AS attachment_severity,
    a.analysis:sensitive_elements AS attachment_concerns,
    
    -- Overall assessment
    CASE 
        WHEN e.analysis:severity::STRING = 'CRITICAL' 
          OR a.analysis:severity::STRING = 'CRITICAL' THEN 'CRITICAL'
        WHEN e.analysis:severity::STRING = 'SENSITIVE' 
          OR a.analysis:severity::STRING = 'SENSITIVE' THEN 'SENSITIVE'
        WHEN e.analysis:severity::STRING = 'POTENTIALLY_SENSITIVE' 
          OR a.analysis:severity::STRING = 'POTENTIALLY_SENSITIVE' THEN 'POTENTIALLY_SENSITIVE'
        ELSE 'CLEAN'
    END AS overall_severity,
    
    CASE 
        WHEN e.analysis:severity::STRING = 'CRITICAL' 
          OR a.analysis:severity::STRING = 'CRITICAL' THEN '🚨 ESCALATE IMMEDIATELY'
        WHEN e.analysis:severity::STRING = 'SENSITIVE' 
          OR a.analysis:severity::STRING = 'SENSITIVE' THEN '⚠️ COMPLIANCE REVIEW'
        WHEN e.analysis:severity::STRING = 'POTENTIALLY_SENSITIVE' 
          OR a.analysis:severity::STRING = 'POTENTIALLY_SENSITIVE' THEN '👀 MONITOR'
        ELSE '✅ NO ACTION'
    END AS recommended_action

FROM complete_email_analysis e
LEFT JOIN complete_attachment_analysis a ON e.email_id = a.email_id;

-- Final dashboard
SELECT 
    email_id,
    sender,
    subject,
    overall_severity,
    recommended_action,
    email_summary,
    evidence,
    attachment,
    attachment_concerns
FROM complete_dashboard
ORDER BY 
    CASE overall_severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        WHEN 'POTENTIALLY_SENSITIVE' THEN 3
        ELSE 4
    END;

-- =============================================================================
-- COMPLETE APPROACH SUMMARY
-- =============================================================================

/*
PROS of CORTEX.COMPLETE:
✅ Full control over prompts and output schema
✅ Access to Frontier models (Claude, Llama 405B, etc.)
✅ Custom JSON schemas for your exact needs
✅ Can combine multiple analyses in one call
✅ Deeper reasoning and explanation
✅ Better for complex, nuanced analysis

CONS:
❌ More verbose SQL (longer prompts)
❌ May be slower for simple tasks
❌ Requires prompt engineering
❌ Higher token usage

Next: Compare both approaches side-by-side → 04_comparison.sql
*/

