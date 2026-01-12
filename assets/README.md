# Sample Attachment Files

Mock email attachments for the compliance demo. Upload these to `@compliance_attachments` stage.

## Files Included

| File | Description |
|------|-------------|
| `AAPL_Insider_Analysis.xlsx` | Spreadsheet with insider trading analysis |
| `AAPL_Analysis.png` | Screenshot of the Excel spreadsheet |
| `order_entry_screenshot.png` | Trading system screenshot with coordination evidence |
| `trading_infrastructure_v3.pdf` | Internal architecture diagram |
| `ACME.Finance.Trading.Infra.png` | PNG version of architecture diagram |

## Uploading to Snowflake Stage

```sql
-- Create stage (done in 00_setup.sql)
CREATE STAGE IF NOT EXISTS compliance_attachments;

-- Upload files (run from SnowSQL or Snowsight)
PUT file:///path/to/assets/AAPL_Insider_Analysis.xlsx @compliance_attachments/2024/12/;
PUT file:///path/to/assets/AAPL_Analysis.png @compliance_attachments/2024/12/;
PUT file:///path/to/assets/order_entry_screenshot.png @compliance_attachments/2024/12/;
PUT file:///path/to/assets/trading_infrastructure_v3.pdf @compliance_attachments/2024/12/;
PUT file:///path/to/assets/ACME.Finance.Trading.Infra.png @compliance_attachments/2024/12/;

-- Verify upload
LIST @compliance_attachments;
```

## Using Real Images in the Demo

Once files are uploaded, use `GET_PRESIGNED_URL()` to pass to CORTEX.COMPLETE:

```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'claude-sonnet-4-5',
    'Analyze this image for compliance concerns. Return JSON with violation_type, severity, and concerns.',
    GET_PRESIGNED_URL(@compliance_attachments, '2024/12/order_entry_screenshot.png')
) AS image_analysis;
```

## Note

For the demo worksheets, the `image_description` column in the `email_attachments` table contains text descriptions that simulate image content. This allows the SQL patterns to work without uploading files. For a fully realistic demo, upload the actual files and modify the queries to use `GET_PRESIGNED_URL()`.
