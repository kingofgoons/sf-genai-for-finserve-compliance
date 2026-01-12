# Snowflake GenAI for Financial Services Compliance

A hands-on lab demonstrating Snowflake Cortex AI SQL functions for email communications compliance monitoring.

## Overview

This workshop showcases how Frontier LLMs in Snowflake can transform email analysis for compliance teams. All processing stays within Snowflake's security perimeter—no external API calls required.

## Workshop Structure (60 minutes)

| Worksheet | Duration | Functions Covered |
|-----------|----------|-------------------|
| `00_setup.sql` | 5 min | Database, tables, sample data |
| `01_classification_filtering.sql` | 15 min | `AI_CLASSIFY`, `AI_FILTER` |
| `02_extraction_sentiment.sql` | 15 min | `AI_TRANSLATE`, `AI_EXTRACT`, `AI_SENTIMENT` |
| `03_aggregation_similarity.sql` | 10 min | `AI_AGG`, `AI_EMBED`, `AI_SIMILARITY` |
| `04_multimodal.sql` | 10 min | `AI_COMPLETE`, `AI_TRANSCRIBE` |
| `99_reset.sql` | — | Cleanup |

## Quick Start

1. Open Snowflake Worksheets
2. Copy/paste `worksheets/00_setup.sql` and run
3. Proceed through worksheets 01–04 in order
4. Run `99_reset.sql` to clean up when done

## Project Structure

```
├── worksheets/
│   ├── 00_setup.sql                  # Create database & sample data
│   ├── 01_classification_filtering.sql
│   ├── 02_extraction_sentiment.sql
│   ├── 03_aggregation_similarity.sql
│   ├── 04_multimodal.sql
│   └── 99_reset.sql                  # Cleanup script
└── README.md
```

## AI SQL Functions Covered

| Function | Use Case |
|----------|----------|
| `AI_CLASSIFY` | Categorize emails (insider trading, market manipulation, etc.) |
| `AI_FILTER` | Natural language yes/no filtering |
| `AI_TRANSLATE` | Handle international communications |
| `AI_EXTRACT` | Pull entities: securities, dates, parties |
| `AI_SENTIMENT` | Risk sentiment scoring (-1 to +1) |
| `AI_AGG` | Summarize across groups (e.g., by department) |
| `AI_EMBED` | Create vector embeddings |
| `AI_SIMILARITY` | Find patterns matching historical violations |
| `AI_COMPLETE` | Custom LLM prompts, structured outputs |
| `AI_TRANSCRIBE` | Speech-to-text for recorded calls |

## Sample Data

The setup script creates 5 synthetic emails:
- 🇩🇪 German email (insider trading) — for `AI_TRANSLATE` demo
- 🇫🇷 French email (data exfiltration) — for `AI_TRANSLATE` demo
- 🇺🇸 English emails (various compliance scenarios)

Plus supporting tables for historical violations and compliance incidents.

## Prerequisites

- Snowflake account with Cortex AI SQL functions enabled
- Role with `CREATE DATABASE` privileges (or use existing database)
- Warehouse access

## Resources

- [Cortex AI SQL Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)
- [Available LLMs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#availability): Claude, Llama, Mistral, Snowflake Arctic

## License

Internal demo use only.
