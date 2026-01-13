-- =============================================================================
-- 99_RESET.SQL
-- Clean up all demo objects
-- 
-- Run this to return to a clean slate.
-- =============================================================================

-- Need ACCOUNTADMIN to drop database and role
USE ROLE ACCOUNTADMIN;

-- Drop database (removes all tables, views, stages, schemas)
DROP DATABASE IF EXISTS GENAI_COMPLIANCE_DEMO;

-- Optionally drop warehouse
-- DROP WAREHOUSE IF EXISTS GENAI_HOL_WH;

-- Drop custom role
DROP ROLE IF EXISTS GENAI_COMPLIANCE_ROLE;

SELECT '✅ Demo objects cleaned up. Ready for fresh run.' AS status;
