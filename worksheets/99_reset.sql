-- =============================================================================
-- 99_RESET.SQL
-- Clean up all demo objects
-- 
-- Run this to return to a clean slate before re-running the lab.
-- =============================================================================

-- Drop all demo objects
DROP DATABASE IF EXISTS GENAI_COMPLIANCE_DEMO;
DROP WAREHOUSE IF EXISTS GENAI_HOL_WH;

-- Confirm cleanup
SELECT '✓ Demo objects cleaned up. Ready for fresh run.' AS status;

