-- =============================================================================
-- 03_COMPLETE_APPROACH.SQL
-- Full Compliance Pipeline Using AI_COMPLETE + Frontier Models + Structured Outputs
-- 
-- This approach uses AI_COMPLETE with the response_format parameter to enforce
-- structured JSON outputs. The schema is passed to the model, not just in the prompt.
-- Full control, custom schemas, access to Claude/Llama/Mistral.
-- =============================================================================

USE ROLE GENAI_COMPLIANCE_ROLE;
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
-- STRUCTURED OUTPUT SCHEMA DEFINITIONS
-- These schemas enforce deterministic JSON responses from the model
-- =============================================================================

/*
AI_COMPLETE Structured Outputs enforces JSON schema compliance at the token level.
Key benefits:
• No post-processing needed - response always matches schema
• Reduced hallucination - model can't deviate from structure
• Seamless integration with downstream systems

Schema rules:
• Use 'required' field to ensure critical fields are always present
• Use 'description' field to guide model understanding
• For complex schemas, use $defs for reusable components
• Property names: letters, digits, hyphen, underscore only (max 64 chars)
*/

-- =============================================================================
-- CREATE THE COMPLETE PIPELINE WITH STRUCTURED OUTPUTS
-- Single call per email with enforced JSON schema via response_format
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
    
    -- Full analysis in ONE call with STRUCTURED OUTPUT (response_format parameter)
    -- The schema is enforced at token generation, not just requested in prompt
    PARSE_JSON(
        AI_COMPLETE(
            model => 'claude-sonnet-4-5',
            prompt => 'You are a senior financial services compliance officer. Analyze this email thoroughly.

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
END,
            response_format => {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'violation_type': {
                            'type': 'string',
                            'enum': ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean'],
                            'description': 'The type of compliance violation detected'
                        },
                        'severity': {
                            'type': 'string',
                            'enum': ['CRITICAL', 'SENSITIVE', 'POTENTIALLY_SENSITIVE', 'CLEAN'],
                            'description': 'Severity level based on violation type and evidence'
                        },
                        'confidence': {
                            'type': 'number',
                            'description': 'Confidence score from 0 to 100'
                        },
                        'sentiment': {
                            'type': 'string',
                            'enum': ['negative', 'neutral', 'positive'],
                            'description': 'Overall emotional tone of the email'
                        },
                        'summary': {
                            'type': 'string',
                            'description': '15 word max summary of the compliance concern'
                        },
                        'violating_phrases': {
                            'type': 'array',
                            'items': {'type': 'string'},
                            'description': 'Exact quotes from the email that indicate violations'
                        },
                        'securities_mentioned': {
                            'type': 'array',
                            'items': {'type': 'string'},
                            'description': 'Tickers or company names mentioned'
                        },
                        'concealment_attempts': {
                            'type': 'string',
                            'description': 'Any instructions to delete, hide, or keep information secret'
                        },
                        'recommended_action': {
                            'type': 'string',
                            'enum': ['escalate_immediately', 'compliance_review', 'monitor', 'no_action'],
                            'description': 'Recommended next step for compliance team'
                        },
                        'reasoning': {
                            'type': 'string',
                            'description': 'Brief explanation of the assessment'
                        }
                    },
                    'required': ['violation_type', 'severity', 'confidence', 'sentiment', 'summary', 
                                 'violating_phrases', 'securities_mentioned', 'recommended_action', 'reasoning']
                }
            }
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
-- ATTACHMENT ANALYSIS WITH STRUCTURED OUTPUTS
-- More detailed than AISQL approach with enforced schema
-- =============================================================================

CREATE OR REPLACE VIEW complete_attachment_analysis AS
SELECT 
    a.attachment_id,
    a.email_id,
    a.filename,
    a.file_type,
    
    PARSE_JSON(
        AI_COMPLETE(
            model => 'claude-sonnet-4-5',
            prompt => 'You are a data security analyst reviewing an email attachment.

Analyze this attachment description for security and compliance concerns.

Severity guide:
- CRITICAL: Credentials, internal IPs, or clear policy violation visible
- SENSITIVE: Confidential business info, PII, or internal-only documents
- POTENTIALLY_SENSITIVE: May contain info not meant for external sharing
- CLEAN: No security concerns

Attachment: ' || a.filename || ' (' || a.file_type || ')
Content description: ' || a.image_description,
            response_format => {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'violation_type': {
                            'type': 'string',
                            'enum': ['data_leak', 'insider_info', 'credential_exposure', 'pii_exposure', 'unauthorized_sharing', 'clean'],
                            'description': 'Type of security violation detected'
                        },
                        'severity': {
                            'type': 'string',
                            'enum': ['CRITICAL', 'SENSITIVE', 'POTENTIALLY_SENSITIVE', 'CLEAN'],
                            'description': 'Severity level of the security concern'
                        },
                        'confidence': {
                            'type': 'number',
                            'description': 'Confidence score from 0 to 100'
                        },
                        'sensitive_elements': {
                            'type': 'array',
                            'items': {'type': 'string'},
                            'description': 'Specific sensitive items identified in the attachment'
                        },
                        'risk_factors': {
                            'type': 'array',
                            'items': {'type': 'string'},
                            'description': 'Risk factors that contributed to the assessment'
                        },
                        'recommended_action': {
                            'type': 'string',
                            'enum': ['block', 'quarantine', 'review', 'allow'],
                            'description': 'Recommended action for this attachment'
                        },
                        'reasoning': {
                            'type': 'string',
                            'description': 'Brief explanation of the security assessment'
                        }
                    },
                    'required': ['violation_type', 'severity', 'confidence', 'sensitive_elements', 
                                 'risk_factors', 'recommended_action', 'reasoning']
                }
            }
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
-- REAL IMAGE ANALYSIS (Using TO_FILE() for stage-based images)
-- Uses AI_COMPLETE multimodal capability with Claude models
-- =============================================================================

/*
PREREQUISITE: Upload attachments to the stage before running these queries.

From SnowSQL or Snowsight file upload:
    PUT file:///path/to/assets/order_entry_screenshot.jpg @compliance_attachments/2024/12/ AUTO_COMPRESS=FALSE;
    PUT file:///path/to/assets/trading_infrastructure_v3.jpg @compliance_attachments/2024/12/ AUTO_COMPRESS=FALSE;
    PUT file:///path/to/assets/public_market_summary.jpg @compliance_attachments/2024/12/ AUTO_COMPRESS=FALSE;

Verify upload:
    LIST @compliance_attachments;

IMAGE ANALYSIS SYNTAX:
Use TO_FILE() to reference IMAGES from a stage:
    AI_COMPLETE('model', 'prompt', TO_FILE('@stage', 'path/to/file.png'))

For multiple images, use PROMPT() helper:
    AI_COMPLETE('model', PROMPT('Compare {0} to {1}', TO_FILE(...), TO_FILE(...)))

SUPPORTED FORMATS: .jpg, .jpeg, .png, .webp, .gif ONLY
(PDFs, Excel, Word files NOT supported - use screenshots instead)

Max file size: 3.75 MB for Claude models
Max dimensions: 8000 x 8000 pixels
Max images per prompt: 20 for Claude models

Token cost for Claude: ~(Width × Height) / 750 tokens per image
*/

-- Analyze trading system screenshot for coordinated trading evidence
SELECT 
    'order_entry_screenshot.jpg' AS filename,
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'You are a compliance analyst reviewing a trading system screenshot.
        
Analyze this image for:
- Coordinated trading evidence (multiple orders at same time, annotations)
- Suspicious annotations or handwritten notes
- Visible account numbers or trader IDs
- Evidence of market manipulation

Return your analysis as a JSON object:
{
    "violation_type": "coordinated_trading|market_manipulation|clean",
    "severity": "CRITICAL|SENSITIVE|CLEAN",
    "concerns": ["specific concern 1", "specific concern 2"],
    "visible_identifiers": ["any account numbers or IDs visible"],
    "action": "recommended action"
}

Return ONLY the JSON object.',
        TO_FILE('@compliance_attachments', '2024/12/order_entry_screenshot.jpg')
    ) AS analysis;

-- Analyze architecture diagram screenshot for data leak risk
SELECT 
    'trading_infrastructure_v3.jpg' AS filename,
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'You are a data security analyst reviewing a screenshot of an internal architecture diagram.

Analyze this image for security concerns:
- Exposed IP addresses or server names
- Visible credentials or access keys
- Internal-only markings or classifications
- AWS account IDs or cloud resource identifiers
- Information that should not be shared externally

Return your analysis as a JSON object:
{
    "violation_type": "data_leak|credential_exposure|internal_only|clean",
    "severity": "CRITICAL|SENSITIVE|POTENTIALLY_SENSITIVE|CLEAN",
    "exposed_info": ["specific exposed item 1", "specific exposed item 2"],
    "classification_markings": ["any visible classification labels"],
    "safe_for_external": true/false,
    "reasoning": "brief explanation"
}

Return ONLY the JSON object.',
        TO_FILE('@compliance_attachments', '2024/12/trading_infrastructure_v3.jpg')
    ) AS analysis;

-- Analyze public market data screenshot - should be flagged as CLEAN (no risk)
-- This demonstrates that the AI correctly identifies safe, non-confidential content
SELECT 
    'public_market_summary.jpg' AS filename,
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'You are a compliance analyst reviewing a screenshot of a spreadsheet.

Analyze this image for compliance concerns:
- Is this public or non-public information?
- Are there any confidential markings?
- Does it contain insider information or trade recommendations?
- Is this safe to share externally?

Return your analysis as a JSON object:
{
    "violation_type": "insider_trading|material_nonpublic_info|data_leak|clean",
    "severity": "CRITICAL|SENSITIVE|POTENTIALLY_SENSITIVE|CLEAN",
    "data_classification": "public|internal|confidential|restricted",
    "concerns": ["any concerns found, or empty if none"],
    "safe_for_external": true/false,
    "reasoning": "brief explanation of why this is or is not a compliance concern"
}

Return ONLY the JSON object.',
        TO_FILE('@compliance_attachments', '2024/12/public_market_summary.jpg')
    ) AS analysis;

-- =============================================================================
-- MULTI-IMAGE COMPARISON (Using PROMPT helper)
-- Compare multiple attachments from the same email thread
-- =============================================================================

/*
Use PROMPT() to analyze multiple images in a single call.
Placeholders {0}, {1}, etc. reference the TO_FILE() arguments in order.
NOTE: Avoid curly braces in prompt text - use natural language for JSON keys.
*/

-- Compare violation vs clean images to demonstrate AI differentiation
SELECT 
    'Multi-image comparison: Violation vs Clean' AS analysis_type,
    AI_COMPLETE(
        'llama4-maverick',
        PROMPT(
            'You are a compliance analyst. Compare image {0} to image {1}.

For EACH image determine:
1. Is it a compliance concern or safe?
2. What severity level: CRITICAL, SENSITIVE, POTENTIALLY_SENSITIVE, or CLEAN?
3. List any key concerns.

Return your analysis as valid JSON with these keys: image_1_assessment, image_2_assessment, comparison_summary.',
            TO_FILE('@compliance_attachments', '2024/12/trading_infrastructure_v3.jpg'),
            TO_FILE('@compliance_attachments', '2024/12/public_market_summary.jpg')
        )
    ) AS analysis;

-- =============================================================================
-- IMAGE CLASSIFICATION WITH AI_CLASSIFY
-- Quick categorization without full analysis
-- =============================================================================

-- Classify image type for routing
SELECT 
    'order_entry_screenshot.jpg' AS filename,
    AI_CLASSIFY(
        TO_FILE('@compliance_attachments', '2024/12/order_entry_screenshot.jpg'),
        ['Trading System Screenshot', 'Financial Spreadsheet Screenshot', 'Architecture Diagram', 
         'Email Screenshot', 'Legal Document Screenshot', 'Marketing Material']
    ) AS document_classification;

-- Multi-label classification for compliance concerns - compare violation vs clean
SELECT 
    'trading_infrastructure_v3.jpg (should flag confidential)' AS filename,
    AI_CLASSIFY(
        TO_FILE('@compliance_attachments', '2024/12/trading_infrastructure_v3.jpg'),
        ['Contains Confidential Markings', 'Contains Internal IPs', 'Contains Server Names',
         'Safe for External Sharing', 'Public Information'],
        {'output_mode': 'multi'}
    ) AS compliance_labels;

SELECT 
    'public_market_summary.jpg (should flag safe/public)' AS filename,
    AI_CLASSIFY(
        TO_FILE('@compliance_attachments', '2024/12/public_market_summary.jpg'),
        ['Contains Confidential Markings', 'Contains Internal IPs', 'Contains Server Names',
         'Safe for External Sharing', 'Public Information'],
        {'output_mode': 'multi'}
    ) AS compliance_labels;

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
-- COMPLETE APPROACH WITH STRUCTURED OUTPUTS + MULTIMODAL - SUMMARY
-- =============================================================================

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TWO KEY CAPABILITIES DEMONSTRATED                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. STRUCTURED OUTPUTS (for text analysis)                                  │
│     Uses response_format parameter to guarantee JSON schema compliance      │
│                                                                             │
│  2. MULTIMODAL ANALYSIS (for images/documents)                              │
│     Uses TO_FILE() to analyze images, PDFs, spreadsheets from stages        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

STRUCTURED OUTPUTS SYNTAX:
    AI_COMPLETE(
        model => 'claude-sonnet-4-5',
        prompt => 'Analyze this email...',
        response_format => {
            'type': 'json',
            'schema': {
                'type': 'object',
                'properties': {...},
                'required': [...]
            }
        }
    )

BENEFITS OF STRUCTURED OUTPUTS:
✅ Schema enforced at token generation (not just requested)
✅ Guaranteed valid JSON matching your schema
✅ Enum constraints ensure valid categorical values
✅ Required fields always present in output
✅ Seamless integration with downstream systems

MULTIMODAL SYNTAX:
    -- Single image
    AI_COMPLETE('claude-3-5-sonnet', 'prompt', TO_FILE(@stage, 'file.png'))
    
    -- Multiple images with PROMPT() helper
    AI_COMPLETE('claude-3-5-sonnet', 
        PROMPT('Compare {0} to {1}', TO_FILE(@stage, 'a.png'), TO_FILE(@stage, 'b.png')))
    
    -- Image classification
    AI_CLASSIFY(TO_FILE(@stage, 'file.png'), ['Category1', 'Category2'])

MULTIMODAL REQUIREMENTS (Claude models):
• Supported formats: .jpg, .jpeg, .png, .webp, .gif
• Max file size: 3.75 MB per image
• Max dimensions: 8000x8000 pixels
• Max images per prompt: 20
• Token cost: ~(Width × Height) / 750 tokens per image

SCHEMA BEST PRACTICES:
• Use 'enum' for categorical values to constrain outputs
• Use 'description' for each field to improve accuracy
• Use 'required' array to ensure critical fields
• Keep property names simple (letters, digits, hyphen, underscore)
• For complex schemas, use $defs for reusable components

┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE APPROACH SUMMARY                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PROS:                                                                      │
│  ✅ Full control over prompts and output schema                             │
│  ✅ Access to Frontier models (Claude, Llama, Mistral, OpenAI)              │
│  ✅ GUARANTEED JSON conformance via response_format                         │
│  ✅ MULTIMODAL: Analyze images, screenshots, documents, charts              │
│  ✅ Multi-image comparison in single call                                   │
│  ✅ AI_CLASSIFY for quick image categorization                              │
│  ✅ Deeper reasoning and explanation                                        │
│                                                                             │
│  CONS:                                                                      │
│  ❌ More verbose SQL (longer schema definitions)                            │
│  ❌ May be slower for simple tasks                                          │
│  ❌ Schema complexity increases token usage                                 │
│  ❌ Image analysis has per-image token costs                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Next: Compare both approaches side-by-side → 04_comparison.sql
*/
