# Snowflake GenAI for Financial Services Compliance

A hands-on lab demonstrating Snowflake Cortex AI SQL functions for email communications compliance monitoring.

## Overview

This demo showcases how Frontier LLMs in Snowflake can transform email analysis for compliance teams. All processing stays within Snowflake's security perimeter—no external API calls required.

### Key Capabilities

| Function | Compliance Use Case |
|----------|---------------------|
| `AI_CLASSIFY` | Categorize emails (insider trading, market manipulation, data exfiltration) |
| `AI_FILTER` | Natural language filtering for suspicious communications |
| `AI_EXTRACT` | Extract securities, price targets, counterparties from emails |
| `AI_SENTIMENT` | Detect risk indicators via sentiment scoring (-1 to 1) |
| `AI_AGG` | Aggregate insights across compliance incidents |
| `AI_SIMILARITY` | Find patterns in historical violations |
| `AI_TRANSCRIBE` | Process recorded compliance calls |
| `AI_TRANSLATE` | Handle international communications |
| `AI_COMPLETE` | Custom prompts for nuanced detection (including images) |

## Demo Structure (60 minutes)

| Block | Duration | Focus |
|-------|----------|-------|
| Intro | 5 min | Cortex AI SQL overview, available LLMs (Claude, Llama, Mistral, Arctic) |
| Demo 1 | 15 min | Text Classification & Filtering |
| Demo 2 | 15 min | Information Extraction & Sentiment |
| Demo 3 | 10 min | Aggregation & Similarity |
| Demo 4 | 10 min | Multimodal (transcription, image analysis) |
| Q&A | 5 min | Discussion |

## Project Structure

```
├── src/
│   └── app.py              # Streamlit app with 4 demo blocks
├── data/
│   └── sample_emails.sql   # Synthetic email dataset (~500 emails)
├── assets/                 # Document scans, attachments for multimodal demo
├── scripts/
│   └── reset_demo.sql      # Cleanup script
├── requirements.txt
└── README.md
```

## Prerequisites

- Snowflake account with Cortex AI SQL functions enabled
- Python 3.9+
- Warehouse with sufficient compute

## Quick Start

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Load sample data:**
   ```bash
   snowsql -f data/sample_emails.sql
   ```

3. **Run the demo app:**
   ```bash
   streamlit run src/app.py
   ```

## Sample Queries

### Classification & Filtering
```sql
-- Classify emails and filter for material non-public info
SELECT email_id, sender,
       AI_CLASSIFY(email_content,
                   ['insider_trading', 'market_manipulation', 'clean']) AS risk_category,
       AI_FILTER(email_content, 'Does this mention non-public information?') AS material_info_flag
FROM compliance_emails;
```

### Extraction & Sentiment
```sql
-- Extract entities and score sentiment
SELECT trader_id,
       AI_EXTRACT(email_content, 'What securities are mentioned?') AS securities,
       AI_SENTIMENT(email_content) AS risk_sentiment
FROM trading_communications;
```

### Aggregation by Department
```sql
-- Summarize compliance risks by department
SELECT department,
       AI_AGG(incident_description, 'Summarize the main compliance risks') AS risk_summary
FROM compliance_incidents
GROUP BY department;
```

## Reset Demo

```bash
snowsql -f scripts/reset_demo.sql
```

## Resources

- [Cortex AI SQL Functions Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)
- [AI SQL Public Preview Announcement](https://docs.snowflake.com/en/release-notes/2025/other/2025-06-02-cortex-aisql-public-preview)

## License

Internal demo use only.
