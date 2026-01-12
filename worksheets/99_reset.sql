-- =============================================================================
-- 99_RESET.SQL
-- Clean up all demo objects
-- 
-- Run this to return to a clean slate.
-- =============================================================================

USE DATABASE GENAI_COMPLIANCE_DEMO;

-- Drop views created in worksheets
DROP VIEW IF EXISTS complete_dashboard;
DROP VIEW IF EXISTS complete_full_analysis;
DROP VIEW IF EXISTS complete_attachment_analysis;
DROP VIEW IF EXISTS complete_email_analysis;
DROP VIEW IF EXISTS aisql_attachment_analysis;
DROP VIEW IF EXISTS aisql_email_analysis;

-- Drop stage
DROP STAGE IF EXISTS compliance_attachments;

-- Drop database (removes all tables, schemas)
DROP DATABASE IF EXISTS GENAI_COMPLIANCE_DEMO;

-- Optionally drop warehouse
-- DROP WAREHOUSE IF EXISTS GENAI_HOL_WH;

SELECT '✅ Demo objects cleaned up. Ready for fresh run.' AS status;
