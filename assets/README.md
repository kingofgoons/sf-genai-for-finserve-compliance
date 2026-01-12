# Sample Attachment Files

This folder contains mock email attachments for the compliance demo.

## Files to Create

Upload these to the `@compliance_attachments` Snowflake stage.

### 1. AAPL_Insider_Analysis.xlsx
**Screenshot of a spreadsheet showing insider trading analysis**

Create in Excel/Sheets with:
- Columns: "Insider Source", "Expected EPS", "Consensus EPS", "Trade Recommendation"
- A highlighted cell showing "BUY BEFORE ANNOUNCEMENT"
- Footer text: "CONFIDENTIAL - DO NOT DISTRIBUTE"
- Optional: Chart showing expected price movement

Save as screenshot (PNG) or actual XLSX.

---

### 2. order_entry_screenshot.png
**Screenshot of a trading system with coordination evidence**

Create a mockup showing:
- Bloomberg-style or trading platform UI
- Multiple pending orders for NVDA
- All orders timestamped at 10:15:00 AM
- Red handwritten annotation: "COORDINATE WITH TEAM - SAME TIME"
- Partially visible account numbers

Tools: Figma, Canva, or screenshot from a demo trading platform.

---

### 3. trading_infrastructure_v3.pdf
**Internal architecture diagram (not for external sharing)**

Create a network diagram showing:
- Title: "ACME Finance - Trading Infrastructure v3.0"
- Components: Trading Engine, NYSE/NASDAQ feeds, Portfolio Database, Risk System
- Visible IP addresses (e.g., 10.0.1.50)
- Server names (e.g., PROD-DB-01)
- AWS account ID in corner (fake: 123456789012)
- Large red watermark: "INTERNAL USE ONLY - NOT FOR EXTERNAL DISTRIBUTION"
- Footer: "Classification: HIGHLY CONFIDENTIAL"

Tools: draw.io, Lucidchart, Excalidraw, or PowerPoint.

---

## Uploading to Snowflake Stage

```sql
-- Create stage (done in 00_setup.sql)
CREATE STAGE IF NOT EXISTS compliance_attachments;

-- Upload files (run from SnowSQL or Snowsight)
PUT file:///path/to/AAPL_Insider_Analysis.xlsx @compliance_attachments/2024/12/;
PUT file:///path/to/order_entry_screenshot.png @compliance_attachments/2024/12/;
PUT file:///path/to/trading_infrastructure_v3.pdf @compliance_attachments/2024/12/;

-- Verify upload
LIST @compliance_attachments;
```

## Using Real Images in the Demo

Once files are uploaded, use `GET_PRESIGNED_URL()` to pass to CORTEX.COMPLETE:

```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'claude-sonnet-4-5',
    'Analyze this image for compliance concerns...',
    GET_PRESIGNED_URL(@compliance_attachments, '2024/12/order_entry_screenshot.png')
) AS image_analysis;
```

## Note

For the demo, the `image_description` column in `email_attachments` table contains text descriptions that simulate image content. This works for demonstrating the SQL patterns without needing actual files.

