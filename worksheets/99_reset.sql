-- =============================================================================
-- 99_RESET.SQL
-- Clean up all demo objects
-- 
-- Run this to return to a clean slate.
-- =============================================================================

-- Drop views first
DROP VIEW IF EXISTS GENAI_COMPLIANCE_DEMO.PUBLIC.compliance_dashboard;
DROP VIEW IF EXISTS GENAI_COMPLIANCE_DEMO.PUBLIC.attachment_analysis;
DROP VIEW IF EXISTS GENAI_COMPLIANCE_DEMO.PUBLIC.email_analysis;

-- Drop database (removes all tables)
DROP DATABASE IF EXISTS GENAI_COMPLIANCE_DEMO;

-- Optionally drop warehouse
-- DROP WAREHOUSE IF EXISTS GENAI_HOL_WH;

SELECT '✅ Demo objects cleaned up. Ready for fresh run.' AS status;
