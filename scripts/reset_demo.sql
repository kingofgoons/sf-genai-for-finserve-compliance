-- =============================================================================
-- Reset Script: Clean up all demo objects
-- Run this to return to a clean slate before re-running the demo
-- =============================================================================

-- Drop demo database (removes all tables, schemas, etc.)
DROP DATABASE IF EXISTS GENAI_COMPLIANCE_DEMO;

-- Confirm cleanup
SELECT 'Demo objects cleaned up successfully.' AS status;

