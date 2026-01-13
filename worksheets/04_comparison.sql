-- =============================================================================
-- 04_COMPARISON.SQL
-- Compare Approaches: AISQL vs CORTEX.COMPLETE
-- 
-- See the differences, especially for image handling.
-- Choose the approach that fits YOUR use case.
-- =============================================================================

USE ROLE GENAI_COMPLIANCE_ROLE;
USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- SIDE-BY-SIDE: Text Analysis Results
-- =============================================================================

SELECT 
    'AISQL' AS approach,
    a.email_id,
    a.subject,
    a.violations_list AS violation_type,
    a.compliance_flag AS severity,
    a.violation_count AS violation_count
FROM aisql_email_analysis a

UNION ALL

SELECT 
    'COMPLETE',
    c.email_id,
    c.subject,
    c.analysis:violation_type::STRING,
    c.analysis:severity::STRING,
    c.analysis:confidence::NUMBER
FROM complete_email_analysis c

ORDER BY email_id, approach;

-- =============================================================================
-- KEY DIFFERENCE: Image/Attachment Analysis
-- AISQL cannot do this - COMPLETE is required
-- =============================================================================

-- AISQL approach can only analyze attachment text descriptions
SELECT 
    'AISQL Limitation' AS note,
    a.email_id,
    a.filename,
    a.file_type,
    'Can only classify text description' AS capability,
    a.violations_list AS detected_violations
FROM aisql_attachment_analysis a;

-- COMPLETE approach analyzes actual image content
SELECT 
    'COMPLETE Capability' AS note,
    c.email_id,
    c.filename,
    c.analysis:violation_type::STRING AS detected_violation,
    c.analysis:severity::STRING AS severity,
    c.analysis:sensitive_elements AS what_was_found
FROM complete_attachment_analysis c;

-- =============================================================================
-- THE BIG PICTURE: Why Images Matter for Compliance
-- =============================================================================

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WHY IMAGE ANALYSIS IS CRITICAL                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Email text might say:                                                      │
│    "See attached analysis"                                                  │
│                                                                             │
│  But the ATTACHMENT contains:                                               │
│    • Screenshot of trading system with coordination notes                   │
│    • Spreadsheet labeled "BUY BEFORE ANNOUNCEMENT"                          │
│    • Architecture diagram with internal IPs and credentials                 │
│                                                                             │
│  WITHOUT image analysis, you miss 50%+ of the evidence.                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

-- Show how attachments escalate risk
SELECT 
    c.email_id,
    c.subject,
    c.email_severity,
    c.attachment AS attachment_file,
    c.attachment_severity,
    c.overall_severity,
    CASE 
        WHEN c.attachment_severity IN ('CRITICAL', 'SENSITIVE') 
         AND c.email_severity NOT IN ('CRITICAL', 'SENSITIVE')
        THEN TRUE ELSE FALSE 
    END AS attachment_escalates_risk,
    CASE 
        WHEN c.attachment_severity IN ('CRITICAL', 'SENSITIVE') 
        THEN '⚠️ Attachment contains additional violations'
        ELSE ''
    END AS note
FROM complete_dashboard c
WHERE c.attachment IS NOT NULL;

-- =============================================================================
-- APPROACH COMPARISON SUMMARY
-- =============================================================================

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CHOOSE YOUR APPROACH                                │
├────────────────────┬────────────────────────────────────────────────────────┤
│                    │  AISQL Functions      │  CORTEX.COMPLETE              │
├────────────────────┼───────────────────────┼────────────────────────────────┤
│  Text Analysis     │  ✅ Fast, simple      │  ✅ Full control              │
│  Classification    │  ✅ AI_CLASSIFY       │  ✅ Custom categories         │
│  Entity Extraction │  ✅ AI_EXTRACT        │  ✅ Custom schemas            │
│  Sentiment         │  ✅ AI_SENTIMENT      │  ✅ Custom scales             │
│  Translation       │  ✅ AI_TRANSLATE      │  ✅ Use AI_TRANSLATE          │
├────────────────────┼───────────────────────┼────────────────────────────────┤
│  IMAGE ANALYSIS    │  ❌ NOT SUPPORTED     │  ✅ FULL MULTIMODAL           │
│  Screenshots       │  ❌                   │  ✅ Analyze UI, annotations   │
│  Spreadsheets      │  ❌                   │  ✅ Read visible content      │
│  Diagrams          │  ❌                   │  ✅ Detect sensitive info     │
│  Documents         │  ❌                   │  ✅ OCR + analysis            │
├────────────────────┼───────────────────────┼────────────────────────────────┤
│  Best For          │  Quick text analysis  │  Full compliance pipeline     │
│                    │  High volume, simple  │  Complex analysis + images    │
└────────────────────┴───────────────────────┴────────────────────────────────┘
*/

-- =============================================================================
-- RECOMMENDATION: HYBRID APPROACH
-- =============================================================================

-- Best of both worlds: Use each where it excels

SELECT 
    e.email_id,
    e.sender,
    e.subject,
    
    -- Use AI_TRANSLATE (efficient, purpose-built)
    CASE 
        WHEN e.lang != 'en' THEN e.lang || ' → en'
        ELSE 'English (no translation)'
    END AS translation_handled_by_aisql,
    
    -- Use COMPLETE for analysis (powerful, flexible)
    PARSE_JSON(
        SNOWFLAKE.CORTEX.COMPLETE(
            'claude-sonnet-4-5',
            'Quick compliance check. Return JSON: {"risk": "high/medium/low", "reason": "..."}
            
            Email: ' || CASE 
                WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
                ELSE e.email_content
            END
        )
    ) AS complete_analysis,
    
    -- Attachment analysis ONLY possible with COMPLETE
    CASE 
        WHEN e.has_attachment THEN 'Requires COMPLETE for image analysis'
        ELSE 'No attachment'
    END AS attachment_note
    
FROM compliance_emails e
WHERE e.email_id IN (1, 2, 3);

-- =============================================================================
-- FINAL SUMMARY
-- =============================================================================

-- Overall violation counts
SELECT 
    overall_severity,
    COUNT(*) AS count,
    SUM(CASE 
        WHEN attachment_severity IN ('CRITICAL', 'SENSITIVE') 
         AND email_severity NOT IN ('CRITICAL', 'SENSITIVE')
        THEN 1 ELSE 0 
    END) AS escalated_by_attachment
FROM complete_dashboard
GROUP BY overall_severity
ORDER BY 
    CASE overall_severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'SENSITIVE' THEN 2
        WHEN 'POTENTIALLY_SENSITIVE' THEN 3
        ELSE 4
    END;

-- =============================================================================
-- DEMO COMPLETE!
-- =============================================================================

/*
WHAT WE COVERED:

1. BUILDING BLOCKS (01)
   └─ TRANSLATE → SENTIMENT → CLASSIFY → EXTRACT

2. AISQL APPROACH (02)
   └─ Full text pipeline with fine-tuned functions
   └─ Fast, convenient, but TEXT ONLY

3. COMPLETE APPROACH (03)
   └─ Full text pipeline with Frontier models
   └─ PLUS image attachment analysis ⭐

4. COMPARISON (04)
   └─ AISQL: Good for text, no images
   └─ COMPLETE: Full control, handles everything
   └─ HYBRID: Combine both for best results

KEY TAKEAWAY:
┌─────────────────────────────────────────────────────────────────┐
│  For TEXT ONLY: Either approach works                          │
│  For TEXT + IMAGES: You NEED CORTEX.COMPLETE                   │
│                                                                 │
│  Recommendation: Use COMPLETE with structured outputs           │
│  for maximum flexibility and multimodal support.               │
└─────────────────────────────────────────────────────────────────┘

Cleanup: Run 99_reset.sql when done.
*/
