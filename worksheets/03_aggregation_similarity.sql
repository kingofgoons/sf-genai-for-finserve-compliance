-- =============================================================================
-- 03_AGGREGATION_SIMILARITY.SQL
-- Demo Block 3: Aggregation & Similarity (10 min)
-- 
-- Functions covered:
--   • AI_AGG        - Aggregate/summarize text across multiple rows
--   • AI_EMBED      - Create vector embeddings for text
--   • AI_SIMILARITY - Calculate similarity between embeddings
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- AI_AGG: Aggregate insights across groups
-- Summarize themes from multiple records using GROUP BY
-- =============================================================================

-- Example 1: Summarize compliance incidents by department
SELECT 
    department,
    COUNT(*) AS incident_count,
    AI_AGG(
        incident_description,
        'Summarize the main compliance risks and common themes'
    ) AS risk_summary
FROM compliance_incidents
GROUP BY department
ORDER BY incident_count DESC;

-- Example 2: Different aggregation prompts
SELECT 
    department,
    AI_AGG(
        incident_description,
        'List the key action items needed to address these issues'
    ) AS action_items
FROM compliance_incidents
GROUP BY department;

-- Example 3: Aggregate by severity
SELECT 
    severity,
    COUNT(*) AS count,
    AI_AGG(
        incident_description,
        'What are the common patterns in these incidents?'
    ) AS patterns
FROM compliance_incidents
GROUP BY severity
ORDER BY 
    CASE severity 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        ELSE 4 
    END;

-- Example 4: Summarize flagged emails by department
SELECT 
    department,
    COUNT(*) AS flagged_count,
    AI_AGG(
        email_content,
        'Summarize the compliance concerns found in these communications'
    ) AS concerns_summary
FROM compliance_emails
WHERE compliance_flag = TRUE
GROUP BY department;

-- =============================================================================
-- AI_EMBED: Create vector embeddings
-- Convert text to numerical vectors for similarity comparison
-- =============================================================================

-- Example 1: Create embeddings for emails
SELECT 
    email_id,
    subject,
    AI_EMBED('e5-base-v2', email_content) AS embedding
FROM compliance_emails
LIMIT 3;

-- Example 2: Store embeddings in a table for reuse
CREATE OR REPLACE TABLE email_embeddings AS
SELECT 
    email_id,
    email_content,
    AI_EMBED('e5-base-v2', email_content) AS embedding
FROM compliance_emails;

SELECT * FROM email_embeddings;

-- =============================================================================
-- AI_SIMILARITY: Compare text similarity
-- Find emails similar to known violations
-- =============================================================================

-- Example 1: Direct similarity between two texts
SELECT AI_SIMILARITY(
    AI_EMBED('e5-base-v2', 'Got a tip about the upcoming merger announcement'),
    AI_EMBED('e5-base-v2', 'I heard confidential news about the acquisition deal')
) AS similarity_score;

-- Example 2: Find emails similar to a known insider trading violation
WITH known_violation AS (
    SELECT 
        email_content,
        AI_EMBED('e5-base-v2', email_content) AS violation_embedding
    FROM historical_violations
    WHERE violation_type = 'insider_trading'
    LIMIT 1
)
SELECT 
    e.email_id,
    e.sender,
    e.subject,
    AI_SIMILARITY(
        AI_EMBED('e5-base-v2', e.email_content), 
        kv.violation_embedding
    ) AS similarity_to_violation
FROM compliance_emails e
CROSS JOIN known_violation kv
ORDER BY similarity_to_violation DESC;

-- Example 3: Find emails similar to market manipulation pattern
WITH manipulation_pattern AS (
    SELECT AI_EMBED('e5-base-v2', email_content) AS pattern_embedding
    FROM historical_violations
    WHERE violation_type = 'market_manipulation'
    LIMIT 1
)
SELECT 
    e.email_id,
    e.subject,
    LEFT(e.email_content, 80) || '...' AS preview,
    AI_SIMILARITY(
        AI_EMBED('e5-base-v2', e.email_content), 
        mp.pattern_embedding
    ) AS similarity_score,
    CASE 
        WHEN AI_SIMILARITY(AI_EMBED('e5-base-v2', e.email_content), mp.pattern_embedding) > 0.7 
        THEN '🔴 HIGH MATCH'
        WHEN AI_SIMILARITY(AI_EMBED('e5-base-v2', e.email_content), mp.pattern_embedding) > 0.5 
        THEN '🟡 MODERATE MATCH'
        ELSE '🟢 LOW MATCH'
    END AS match_level
FROM compliance_emails e
CROSS JOIN manipulation_pattern mp
ORDER BY similarity_score DESC;

-- =============================================================================
-- COMBINED: Proactive violation detection
-- Compare all new emails against all known violation patterns
-- =============================================================================

WITH violation_patterns AS (
    SELECT 
        violation_type,
        AI_EMBED('e5-base-v2', email_content) AS pattern_embedding
    FROM historical_violations
)
SELECT 
    e.email_id,
    e.sender,
    e.subject,
    vp.violation_type AS matched_pattern,
    ROUND(AI_SIMILARITY(
        AI_EMBED('e5-base-v2', e.email_content), 
        vp.pattern_embedding
    ), 3) AS similarity_score
FROM compliance_emails e
CROSS JOIN violation_patterns vp
WHERE AI_SIMILARITY(
    AI_EMBED('e5-base-v2', e.email_content), 
    vp.pattern_embedding
) > 0.5
ORDER BY similarity_score DESC;

-- =============================================================================
-- TRY IT YOURSELF
-- =============================================================================

-- Your turn: Write a custom aggregation prompt
SELECT 
    department,
    AI_AGG(incident_description, 'YOUR AGGREGATION PROMPT HERE') AS your_summary
FROM compliance_incidents
GROUP BY department;

-- Your turn: Check similarity to your own pattern
SELECT 
    email_id,
    subject,
    AI_SIMILARITY(
        AI_EMBED('e5-base-v2', email_content),
        AI_EMBED('e5-base-v2', 'YOUR PATTERN TEXT HERE')
    ) AS similarity
FROM compliance_emails
ORDER BY similarity DESC;

