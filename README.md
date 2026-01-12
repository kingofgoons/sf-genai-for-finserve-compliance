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
│  Full text pipeline using CORTEX.COMPLETE + Frontier models                  │
│  → Then layer in IMAGE ATTACHMENTS (multimodal analysis)                     │
├──────────────────────────────────────────────────────────────────────────────┤
│  Layer 4: COMPARISON                                                         │
│  Compare approaches, note COMPLETE handles images where AISQL cannot         │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Workshop Structure

| Worksheet | Layer | Focus |
|-----------|-------|-------|
| `00_setup.sql` | — | Create database, emails, stage-based attachments |
| `01_building_blocks.sql` | 1 | Learn functions: TRANSLATE → SENTIMENT → CLASSIFY → EXTRACT |
| `02_aisql_approach.sql` | 2 | Full text pipeline with fine-tuned AI SQL |
| `03_complete_approach.sql` | 3 | Text pipeline + **image attachments** with Frontier models |
| `04_comparison.sql` | 4 | Compare approaches, choose your pathway |
| `99_reset.sql` | — | Cleanup |

## Two Approaches

| Approach | Text Analysis | Image Analysis | Best For |
|----------|---------------|----------------|----------|
| **AI SQL** | ✅ TRANSLATE, CLASSIFY, EXTRACT, SENTIMENT | ❌ Not supported | Quick text analysis |
| **COMPLETE** | ✅ Custom prompts + structured JSON | ✅ Multimodal (Claude) | Full control + images |

**Key insight:** AISQL functions are convenient for text, but **CORTEX.COMPLETE is required for image/attachment analysis**.

## Sample Data

**Emails (5):**
- 🇩🇪 German email (insider trading)
- 🇫🇷 French email (data exfiltration)  
- 🇺🇸 English emails (market manipulation, clean)

**Attachments (3) — stored on `@compliance_attachments` stage:**
| File | Type | Content |
|------|------|---------|
| `@compliance_attachments/.../AAPL_Insider_Analysis.xlsx` | Spreadsheet | "BUY BEFORE ANNOUNCEMENT" |
| `@compliance_attachments/.../order_entry_screenshot.png` | Screenshot | Trading system with coordination notes |
| `@compliance_attachments/.../trading_infrastructure.pdf` | Diagram | Internal architecture, IPs, "NOT FOR EXTERNAL" |

## Violation Levels

| Level | Description |
|-------|-------------|
| `CRITICAL` | Clear policy violation, immediate escalation |
| `SENSITIVE` | Contains confidential information |
| `POTENTIALLY_SENSITIVE` | Warrants review |
| `CLEAN` | No concerns |

## Functions Covered

| Function | Layer | Purpose |
|----------|-------|---------|
| `AI_TRANSLATE` | 1-2 | Auto-detect and translate languages |
| `AI_SENTIMENT` | 1-2 | Score emotional tone (-1 to +1) |
| `AI_CLASSIFY` | 1-2 | Categorize into violation types |
| `AI_EXTRACT` | 1-2 | Pull specific violating phrases |
| `CORTEX.COMPLETE` | 3 | Text + **image analysis** with Frontier models |

## Quick Start

1. Open Snowflake Worksheets
2. Run `00_setup.sql` to create database and sample data
3. Follow worksheets `01` → `02` → `03` → `04` in order
4. Run `99_reset.sql` to clean up

## Prerequisites

- Snowflake account with Cortex AI enabled
- Role with `CREATE DATABASE` and `CREATE STAGE` privileges

## Resources

- [Cortex AI SQL Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)
- [Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Cortex Multimodal](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-multimodal)
