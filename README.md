# Snowflake GenAI for Financial Services Compliance

A demonstration of Snowflake's GenAI capabilities applied to financial services compliance use cases.

## Overview

This project showcases how to leverage Snowflake Cortex AI functions for:
- Document analysis and summarization
- Compliance policy extraction
- Risk assessment automation
- Regulatory text classification

## Project Structure

```
├── src/                 # Application code
│   └── app.py           # Main Streamlit application
├── data/                # Mock/sample data
│   └── sample_docs.sql  # Sample compliance documents
├── assets/              # Images and static files
├── scripts/
│   └── reset_demo.sql   # Cleanup script for demo objects
├── requirements.txt     # Python dependencies
└── README.md
```

## Prerequisites

- Snowflake account with Cortex AI enabled
- Python 3.9+
- Access to a warehouse with sufficient compute

## Quick Start

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure Snowflake connection:**
   - Set environment variables or create `~/.snowflake/connections.toml`

3. **Load sample data:**
   ```bash
   snowsql -f data/sample_docs.sql
   ```

4. **Run the app:**
   ```bash
   streamlit run src/app.py
   ```

## Reset Demo

To clean up all demo objects and start fresh:
```bash
snowsql -f scripts/reset_demo.sql
```

## License

Internal demo use only.

