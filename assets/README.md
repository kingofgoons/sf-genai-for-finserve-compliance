# Sample Attachment Files

Mock email attachments for the compliance demo. Upload these to `@compliance_attachments` stage.

## Files Needed

| File | Type | Compliance Scenario |
|------|------|---------------------|
| `AAPL_Analysis.png` | PNG | Insider trading (VIOLATION) |
| `order_entry_screenshot.jpg` | JPEG | Coordinated trading (VIOLATION) |
| `trading_infrastructure_v3.jpg` | JPEG | Data exfiltration (VIOLATION) |
| `public_market_summary.jpg` | JPEG | Public market data (CLEAN) |

**Supported formats:** `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`  
**Not supported:** `.pdf`, `.xlsx`, `.docx` (use screenshots instead)

## Uploading to Snowflake Stage

```sql
-- From SnowSQL CLI:
USE DATABASE GENAI_COMPLIANCE_DEMO;
USE SCHEMA PUBLIC;

PUT file:///path/to/assets/AAPL_Analysis.png @compliance_attachments/2024/12/ AUTO_COMPRESS=FALSE;
PUT file:///path/to/assets/order_entry_screenshot.jpg @compliance_attachments/2024/12/ AUTO_COMPRESS=FALSE;
PUT file:///path/to/assets/trading_infrastructure_v3.jpg @compliance_attachments/2024/12/ AUTO_COMPRESS=FALSE;
PUT file:///path/to/assets/public_market_summary.jpg @compliance_attachments/2024/12/ AUTO_COMPRESS=FALSE;

-- Verify upload
LIST @compliance_attachments;
```

Or use Snowsight UI: Data → Databases → GENAI_COMPLIANCE_DEMO → PUBLIC → Stages → COMPLIANCE_ATTACHMENTS → "+ Files"

## Using Images in AI_COMPLETE

```sql
-- Single image analysis
SELECT AI_COMPLETE(
    'claude-3-5-sonnet',
    'Analyze this image for compliance concerns.',
    TO_FILE('@compliance_attachments', '2024/12/order_entry_screenshot.jpg')
) AS analysis;

-- Multi-image comparison
SELECT AI_COMPLETE(
    'llama4-maverick',
    PROMPT(
        'Compare image {0} to image {1} for compliance concerns.',
        TO_FILE('@compliance_attachments', '2024/12/trading_infrastructure_v3.jpg'),
        TO_FILE('@compliance_attachments', '2024/12/public_market_summary.jpg')
    )
) AS comparison;
```

## Note

The `image_description` column in `email_attachments` table contains text descriptions that simulate image content. This allows the AISQL functions to work without uploaded files. For full multimodal analysis with `AI_COMPLETE`, upload actual image files.
