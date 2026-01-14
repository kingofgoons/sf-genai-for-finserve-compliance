-- =============================================================================
-- 04_COMPARISON.SQL
-- Compare Approaches: AISQL vs AI_COMPLETE with Structured Outputs
-- 
-- See the differences, especially for:
-- 1. Text analysis (both approaches work)
-- 2. Image handling (COMPLETE required)
-- 3. Schema enforcement (structured outputs advantage)
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

-- COMPLETE approach analyzes actual image content using TO_FILE()
SELECT 
    'AI_COMPLETE + TO_FILE()' AS note,
    c.email_id,
    c.filename,
    c.analysis:violation_type::STRING AS detected_violation,
    c.analysis:severity::STRING AS severity,
    c.analysis:sensitive_elements AS what_was_found
FROM complete_attachment_analysis c;

-- Direct image analysis syntax demonstration
/*
AI_COMPLETE multimodal syntax uses TO_FILE() to reference stage files:

    -- Single image
    AI_COMPLETE('claude-3-5-sonnet', 'prompt', TO_FILE(@stage, 'file.jpg'))
    
    -- Multiple images with PROMPT() helper (placeholders {0}, {1}, etc.)
    AI_COMPLETE('llama4-maverick', 
        PROMPT('Compare {0} to {1}', 
            TO_FILE(@stage, 'a.jpg'), 
            TO_FILE(@stage, 'b.jpg')))
    
    -- Quick classification
    AI_CLASSIFY(TO_FILE(@stage, 'file.jpg'), ['Category1', 'Category2'])
*/

-- =============================================================================
-- KEY DIFFERENCE #2: Schema Enforcement with Structured Outputs
-- =============================================================================

/*
┌───────────────────────────────────────────────────────────────────────────────┐
│                    STRUCTURED OUTPUTS vs PROMPT-BASED JSON                    │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  OLD APPROACH (prompt-based):                                                 │
│    SNOWFLAKE.CORTEX.COMPLETE(                                                 │
│        'claude-sonnet-4-5',                                                   │
│        'Return ONLY valid JSON: {"field": "value"...}'                        │
│    )                                                                          │
│    ↓                                                                          │
│    ❌ Model might include markdown, explanations, or malformed JSON           │
│    ❌ Must use TRY_PARSE_JSON to handle failures                              │
│    ❌ No guarantee of field presence or data types                            │
│                                                                               │
│  NEW APPROACH (response_format parameter):                                    │
│    AI_COMPLETE(                                                               │
│        model => 'claude-sonnet-4-5',                                          │
│        prompt => 'Analyze this email...',                                     │
│        response_format => {'type': 'json', 'schema': {...}}                   │
│    )                                                                          │
│    ↓                                                                          │
│    ✅ JSON schema enforced at token generation                                │
│    ✅ All 'required' fields guaranteed present                                │
│    ✅ 'enum' values constrained to valid options                              │
│    ✅ Safe to use PARSE_JSON directly                                         │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
*/

-- Demonstrate structured output consistency
SELECT 
    email_id,
    subject,
    -- These are GUARANTEED to exist and be valid types due to response_format schema
    analysis:violation_type::STRING AS violation_type,     -- Always one of the enum values
    analysis:severity::STRING AS severity,                 -- Always one of: CRITICAL, SENSITIVE, etc.
    analysis:confidence::NUMBER AS confidence,             -- Always a number 0-100
    analysis:recommended_action::STRING AS action,         -- Always one of the enum values
    ARRAY_SIZE(analysis:violating_phrases) AS evidence_count  -- Array always present
FROM complete_email_analysis
ORDER BY confidence DESC;

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
├────────────────────┬───────────────────────┬────────────────────────────────┤
│                    │  AISQL Functions      │  AI_COMPLETE + Structured      │
├────────────────────┼───────────────────────┼────────────────────────────────┤
│  Text Analysis     │  ✅ Fast, simple      │  ✅ Full control               │
│  Classification    │  ✅ AI_CLASSIFY       │  ✅ Custom categories          │
│  Entity Extraction │  ✅ AI_EXTRACT        │  ✅ Custom schemas             │
│  Sentiment         │  ✅ AI_SENTIMENT      │  ✅ Custom scales              │
│  Translation       │  ✅ AI_TRANSLATE      │  ✅ Use AI_TRANSLATE           │
├────────────────────┼───────────────────────┼────────────────────────────────┤
│  JSON Output       │  ⚠️ Function-specific │  ✅ GUARANTEED by schema       │
│  Custom Schema     │  ❌ Fixed output      │  ✅ Define any structure       │
│  Enum Constraints  │  ❌ Not supported     │  ✅ Enforce valid values       │
├────────────────────┼───────────────────────┼────────────────────────────────┤
│  IMAGE ANALYSIS    │  ❌ NOT SUPPORTED     │  ✅ TO_FILE() + MULTIMODAL     │
│  Screenshots       │  ❌                   │  ✅ Analyze UI, annotations    │
│  Spreadsheets      │  ❌                   │  ✅ Read visible content       │
│  Diagrams          │  ❌                   │  ✅ Detect sensitive info      │
│  Multi-Image       │  ❌                   │  ✅ PROMPT() for comparison    │
│  Image Classify    │  ❌                   │  ✅ AI_CLASSIFY + TO_FILE()    │
├────────────────────┼───────────────────────┼────────────────────────────────┤
│  Best For          │  Quick text analysis  │  Full compliance pipeline      │
│                    │  High volume, simple  │  Complex analysis + images     │
│                    │  Standard categories  │  Custom schemas + multimodal   │
└────────────────────┴───────────────────────┴────────────────────────────────┘

MULTIMODAL SYNTAX REFERENCE:
• Single image: AI_COMPLETE('model', 'prompt', TO_FILE(@stage, 'file.jpg'))
• Multi-image:  AI_COMPLETE('model', PROMPT('Compare {0} to {1}', TO_FILE(...), TO_FILE(...)))
• Classify:     AI_CLASSIFY(TO_FILE(@stage, 'file.jpg'), ['Cat1', 'Cat2'])

SUPPORTED FORMATS: .jpg, .jpeg, .png, .webp, .gif
CLAUDE LIMITS: 3.75 MB per image, 8000x8000 max pixels, 20 images per prompt
*/

-- =============================================================================
-- RECOMMENDATION: HYBRID APPROACH WITH STRUCTURED OUTPUTS
-- =============================================================================

-- Best of both worlds: Use AISQL for translation, AI_COMPLETE for analysis with schema

SELECT 
    e.email_id,
    e.sender,
    e.subject,
    
    -- Use AI_TRANSLATE (efficient, purpose-built)
    CASE 
        WHEN e.lang != 'en' THEN e.lang || ' → en'
        ELSE 'English (no translation)'
    END AS translation_handled_by_aisql,
    
    -- Use AI_COMPLETE with structured output for analysis (powerful, schema-enforced)
    PARSE_JSON(
        AI_COMPLETE(
            model => 'claude-sonnet-4-5',
            prompt => 'Quick compliance risk assessment for this email: ' || 
                CASE 
                    WHEN e.lang != 'en' THEN AI_TRANSLATE(e.email_content, e.lang, 'en')
                    ELSE e.email_content
                END,
            response_format => {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'risk_level': {
                            'type': 'string',
                            'enum': ['high', 'medium', 'low'],
                            'description': 'Overall risk level of the email'
                        },
                        'reason': {
                            'type': 'string',
                            'description': 'Brief explanation of the risk assessment'
                        }
                    },
                    'required': ['risk_level', 'reason']
                }
            }
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
   └─ Individual AI SQL functions for specific tasks

2. AISQL APPROACH (02)
   └─ Full text pipeline with fine-tuned functions
   └─ Fast, convenient, but TEXT ONLY
   └─ Fixed output schemas

3. COMPLETE APPROACH WITH STRUCTURED OUTPUTS (03) ⭐
   └─ Full text pipeline with Frontier models
   └─ PLUS image attachment analysis
   └─ GUARANTEED JSON schema compliance via response_format
   └─ Enum constraints, required fields, custom structures

4. COMPARISON (04)
   └─ AISQL: Good for text, no images, fixed schemas
   └─ COMPLETE + Structured Outputs: Full control, handles everything
   └─ HYBRID: Combine both for best results

KEY TAKEAWAYS:

┌─────────────────────────────────────────────────────────────────┐
│  For TEXT ONLY:                                                 │
│    → AISQL functions for speed and simplicity                   │
│    → AI_COMPLETE for custom analysis                            │
│                                                                 │
│  For TEXT + IMAGES:                                             │
│    → Use AI_COMPLETE with TO_FILE(@stage, 'file.jpg')           │
│    → Use PROMPT() helper for multi-image comparison             │
│    → Use AI_CLASSIFY for quick image categorization             │
│                                                                 │
│  For GUARANTEED JSON SCHEMA:                                    │
│    → Use response_format parameter in AI_COMPLETE               │
│    → Schema enforced at token generation                        │
│    → No more TRY_PARSE_JSON workarounds                         │
│                                                                 │
│  RECOMMENDATION: Use AI_COMPLETE with structured outputs        │
│  for text analysis, and TO_FILE() for multimodal compliance.    │
└─────────────────────────────────────────────────────────────────┘

Cleanup: Run 99_reset.sql when done.
*/
