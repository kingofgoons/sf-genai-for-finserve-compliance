-- =============================================================================
-- 04_MULTIMODAL.SQL
-- Demo Block 4: Multimodal Capabilities (10 min)
-- 
-- Functions covered:
--   • AI_COMPLETE    - General LLM completion (text + images)
--   • AI_TRANSCRIBE  - Speech-to-text processing
--   • Structured outputs with AI_COMPLETE
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;
USE WAREHOUSE GENAI_HOL_WH;

-- =============================================================================
-- AI_COMPLETE: Custom LLM prompts
-- The most flexible function - create any analysis you need
-- =============================================================================

-- Example 1: Basic completion
SELECT AI_COMPLETE(
    'claude-3-5-sonnet',
    'Explain in 2 sentences why insider trading is illegal.'
) AS explanation;

-- Example 2: Analyze an email with custom prompt
SELECT 
    email_id,
    subject,
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'Analyze this email for compliance concerns. 
         Identify: 1) Type of risk, 2) Severity (low/medium/high/critical), 3) Recommended action.
         
         Email: ' || email_content
    ) AS compliance_analysis
FROM compliance_emails
WHERE compliance_flag = TRUE
LIMIT 3;

-- Example 3: Generate a compliance report
SELECT AI_COMPLETE(
    'claude-3-5-sonnet',
    'You are a compliance officer. Based on these flagged emails, write a brief 
     executive summary for the compliance committee:
     
     ' || LISTAGG(email_content, '\n\n---\n\n') WITHIN GROUP (ORDER BY email_id)
) AS executive_summary
FROM compliance_emails
WHERE compliance_flag = TRUE;

-- =============================================================================
-- AI_COMPLETE with Structured Outputs
-- Get consistent JSON responses for integration
-- =============================================================================

-- Example 1: Structured risk assessment
SELECT 
    email_id,
    subject,
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'Analyze this email and return a JSON object with these fields:
         - risk_type: string (insider_trading, market_manipulation, data_exfiltration, clean)
         - severity: string (low, medium, high, critical)  
         - confidence: number (0-100)
         - key_entities: array of strings
         - recommended_action: string
         
         Email: ' || email_content || '
         
         Return ONLY valid JSON, no other text.'
    ) AS structured_analysis
FROM compliance_emails
WHERE compliance_flag = TRUE;

-- Example 2: Parse structured output
SELECT 
    email_id,
    subject,
    PARSE_JSON(
        AI_COMPLETE(
            'claude-3-5-sonnet',
            'Analyze this email and return JSON with fields: risk_type, severity, confidence (0-100).
             Email: ' || email_content || '
             Return ONLY valid JSON.'
        )
    ) AS analysis_json,
    PARSE_JSON(
        AI_COMPLETE(
            'claude-3-5-sonnet',
            'Analyze this email and return JSON with fields: risk_type, severity, confidence (0-100).
             Email: ' || email_content || '
             Return ONLY valid JSON.'
        )
    ):risk_type::STRING AS risk_type,
    PARSE_JSON(
        AI_COMPLETE(
            'claude-3-5-sonnet',
            'Analyze this email and return JSON with fields: risk_type, severity, confidence (0-100).
             Email: ' || email_content || '
             Return ONLY valid JSON.'
        )
    ):confidence::NUMBER AS confidence
FROM compliance_emails
WHERE email_id = 2;

-- =============================================================================
-- AI_TRANSCRIBE: Speech-to-text (conceptual example)
-- Process recorded compliance calls
-- Note: Requires audio files in a Snowflake stage
-- =============================================================================

-- Conceptual example - would require actual audio files in stage
-- CREATE OR REPLACE TABLE recorded_calls (
--     call_id INTEGER,
--     trader_id VARCHAR(50),
--     call_date DATE,
--     audio_file VARCHAR(1000)  -- Stage path like @audio_stage/call_001.mp3
-- );

-- Transcription pipeline (conceptual):
-- SELECT 
--     call_id,
--     trader_id,
--     AI_TRANSCRIBE(audio_file) AS transcript,
--     AI_CLASSIFY(
--         AI_TRANSCRIBE(audio_file),
--         ['insider_trading', 'market_manipulation', 'clean']
--     ) AS risk_category
-- FROM recorded_calls;

-- =============================================================================
-- AI_COMPLETE with Images (conceptual example)
-- Analyze document scans and attachments
-- Note: Requires image files in a Snowflake stage
-- =============================================================================

-- Conceptual example - would require image files in stage
-- SELECT 
--     document_id,
--     AI_COMPLETE(
--         'claude-3-5-sonnet',
--         'Analyze this document image for compliance concerns. 
--          Identify document type, key parties, and any red flags.',
--         BUILD_SCOPED_FILE_URL(@doc_stage, 'trade_confirmation.png')
--     ) AS document_analysis
-- FROM document_scans;

-- =============================================================================
-- AVAILABLE MODELS
-- Different models for different use cases
-- =============================================================================

-- List of available models (check docs for current availability):
-- • claude-3-5-sonnet  - Best for complex reasoning, multimodal
-- • llama3.1-70b       - Good balance of capability and speed
-- • llama3.1-8b        - Faster, good for simpler tasks
-- • mistral-large2     - Strong multilingual support
-- • snowflake-arctic   - Snowflake's native model

-- Compare model outputs
SELECT 
    'claude-3-5-sonnet' AS model,
    AI_COMPLETE('claude-3-5-sonnet', 'What is insider trading? (1 sentence)') AS response
UNION ALL
SELECT 
    'llama3.1-70b',
    AI_COMPLETE('llama3.1-70b', 'What is insider trading? (1 sentence)')
UNION ALL
SELECT 
    'mistral-large2',
    AI_COMPLETE('mistral-large2', 'What is insider trading? (1 sentence)');

-- =============================================================================
-- PUTTING IT ALL TOGETHER: Full compliance pipeline
-- =============================================================================

SELECT 
    email_id,
    sender,
    subject,
    
    -- Translate if needed
    CASE 
        WHEN original_language != 'en' 
        THEN AI_TRANSLATE(email_content, original_language, 'en')
        ELSE email_content
    END AS english_content,
    
    -- Classification
    AI_CLASSIFY(
        CASE WHEN original_language != 'en' 
             THEN AI_TRANSLATE(email_content, original_language, 'en')
             ELSE email_content END,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ):class::STRING AS risk_category,
    
    -- Sentiment
    AI_SENTIMENT(
        CASE WHEN original_language != 'en' 
             THEN AI_TRANSLATE(email_content, original_language, 'en')
             ELSE email_content END
    ) AS sentiment,
    
    -- Custom analysis
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'In 20 words or less, what is the main compliance concern in this email? 
         Email: ' || CASE WHEN original_language != 'en' 
                          THEN AI_TRANSLATE(email_content, original_language, 'en')
                          ELSE email_content END
    ) AS concern_summary
    
FROM compliance_emails
WHERE compliance_flag = TRUE;

-- =============================================================================
-- TRY IT YOURSELF
-- =============================================================================

-- Your turn: Create a custom analysis prompt
SELECT 
    email_id,
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'YOUR CUSTOM PROMPT HERE: ' || email_content
    ) AS your_analysis
FROM compliance_emails
LIMIT 1;

