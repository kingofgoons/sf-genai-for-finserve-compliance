-- =============================================================================
-- Reset Script: Clean up all demo objects
-- Run this to return to a clean slate before re-running the demo
-- =============================================================================

-- Drop demo database (removes all tables, schemas, stages, etc.)
DROP DATABASE IF EXISTS GENAI_COMPLIANCE_DEMO;

-- If using a dedicated stage for attachments/audio files, clean it:
-- DROP STAGE IF EXISTS compliance_stage;

-- Confirm cleanup
SELECT 'Demo objects cleaned up successfully. Ready for fresh run.' AS status;
