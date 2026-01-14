# Snowflake GenAI for Financial Services Compliance

A hands-on lab demonstrating Snowflake Cortex AI for email and attachment compliance monitoring.

## Demo Flow — Layered Complexity

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Layer 1: BUILDING BLOCKS                                                    │
│  Learn each function: TRANSLATE → SENTIMENT → CLASSIFY → EXTRACT             │
├──────────────────────────────────────────────────────────────────────────────┤
│  Layer 2: AISQL APPROACH                                                     │
│  Full text pipeline using fine-tuned AI SQL functions                        │
├──────────────────────────────────────────────────────────────────────────────┤
│  Layer 3: COMPLETE APPROACH                                                  │
│  Full text pipeline using AI_COMPLETE + Frontier models                      │
│  → Then layer in IMAGE ATTACHMENTS (multimodal analysis)                     │
├──────────────────────────────────────────────────────────────────────────────┤
│  Layer 4: COMPARISON                                                         │
│  Compare approaches, note COMPLETE handles images where AISQL cannot         │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Workshop Structure

| Worksheet | Layer | Focus |
|-----------|-------|-------|
| `00_setup.sql` | — | Create database, role, emails, stage-based attachments |
| `01_building_blocks.sql` | 1 | Learn functions: TRANSLATE → SENTIMENT → CLASSIFY → EXTRACT |
| `02_aisql_approach.sql` | 2 | Full text pipeline with fine-tuned AI SQL |
| `03_complete_approach.sql` | 3 | Text pipeline + **image attachments** with Frontier models |
| `04_comparison.sql` | 4 | Compare approaches, choose your pathway |
| `99_reset.sql` | — | Cleanup |

## Two Approaches

| Approach | Text Analysis | Image Analysis | Best For |
|----------|---------------|----------------|----------|
| **AI SQL** | ✅ TRANSLATE, CLASSIFY, EXTRACT, SENTIMENT | ❌ Not supported | Quick text analysis |
| **AI_COMPLETE** | ✅ Custom prompts + structured JSON | ✅ Multimodal (Claude) | Full control + images |

**Key insight:** AISQL functions are convenient for text, but **AI_COMPLETE is required for image/attachment analysis**.

## Sample Data

**Emails (6):**
- 🇩🇪 German email (insider trading)
- 🇫🇷 French email (data exfiltration)  
- 🇺🇸 English emails (insider trading, market manipulation, 2× clean)

**Attachments (4) — stored on `@compliance_attachments/2024/12/` stage:**

| File | Email | Content |
|------|-------|---------|
| `AAPL_Analysis.png` | #2 | Spreadsheet with insider trading analysis, "BUY BEFORE ANNOUNCEMENT" |
| `order_entry_screenshot.jpg` | #3 | Trading system screenshot with coordination notes |
| `trading_infrastructure_v3.jpg` | #5 | Internal architecture diagram, IPs, "NOT FOR EXTERNAL" |
| `public_market_summary.jpg` | #6 | Public market data (CLEAN - no violation) |

## Violation Levels

| Level | Description |
|-------|-------------|
| `CRITICAL` | Clear insider trading or market manipulation, immediate escalation |
| `SENSITIVE` | Confidential information shared inappropriately |
| `POTENTIALLY_SENSITIVE` | Warrants review but may be legitimate |
| `MONITOR` | Negative tone detected, worth watching |
| `CLEAN` | No concerns |

## Functions Covered

| Function | Layer | Purpose |
|----------|-------|---------|
| `AI_TRANSLATE` | 1-2 | Auto-detect and translate languages |
| `AI_SENTIMENT` | 1-2 | Categorical sentiment (confidentiality, timing, deletion, risk) |
| `AI_CLASSIFY` | 1-2 | Multi-label categorization into violation types |
| `AI_EXTRACT` | 1-2 | Pull specific violating phrases and entities |
| `AI_COMPLETE` | 3-4 | Text + **image analysis** with Frontier models + structured JSON output |

## Quick Start

1. Open Snowflake Worksheets
2. Run `00_setup.sql` to create database, role, and sample data
3. Upload images from `assets/` to stage (see `assets/README.md`)
4. Follow worksheets `01` → `02` → `03` → `04` in order
5. Run `99_reset.sql` to clean up

## Prerequisites

- Snowflake account with Cortex AI enabled
- `ACCOUNTADMIN` role (for initial setup only)
- Custom `GENAI_COMPLIANCE_ROLE` is created automatically with least-privilege access

## Security Model

The demo uses a custom role `GENAI_COMPLIANCE_ROLE` with:
- `USAGE` on database, schema, warehouse
- `CREATE TABLE/VIEW/STAGE` permissions
- `SNOWFLAKE.CORTEX_USER` database role for AI functions

## Resources

- [Cortex AI SQL Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)
- [Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Cortex Multimodal](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-multimodal)
- [Regional Model Availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql#regional-availability)
