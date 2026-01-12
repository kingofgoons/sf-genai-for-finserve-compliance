"""
Snowflake GenAI for Financial Services Compliance
Hands-on Lab: Cortex AI SQL Functions for Email Analysis

Demo Structure (60 min):
- Intro (5 min): Overview of AI SQL functions
- Demo 1 (15 min): Classification & Filtering
- Demo 2 (15 min): Extraction & Sentiment
- Demo 3 (10 min): Aggregation & Similarity
- Demo 4 (10 min): Multimodal (transcription, images)
"""

import streamlit as st
from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session

# Page config
st.set_page_config(
    page_title="GenAI Compliance HOL",
    page_icon="🏦",
    layout="wide",
)

# Available LLMs for reference
AVAILABLE_LLMS = ["claude-3-5-sonnet", "llama3.1-70b", "mistral-large2", "snowflake-arctic"]


def get_session() -> Session:
    """Get Snowflake session - works in SiS or local dev."""
    try:
        return get_active_session()
    except Exception:
        connection_params = {
            "account": st.secrets.get("snowflake", {}).get("account", ""),
            "user": st.secrets.get("snowflake", {}).get("user", ""),
            "password": st.secrets.get("snowflake", {}).get("password", ""),
            "warehouse": st.secrets.get("snowflake", {}).get("warehouse", ""),
            "database": st.secrets.get("snowflake", {}).get("database", ""),
            "schema": st.secrets.get("snowflake", {}).get("schema", ""),
        }
        return Session.builder.configs(connection_params).create()


def main():
    st.title("🏦 GenAI for Financial Services Compliance")
    st.markdown("**Hands-on Lab**: Cortex AI SQL Functions for Email Communications Monitoring")

    # Sidebar navigation
    st.sidebar.header("Demo Blocks")
    demo_block = st.sidebar.radio(
        "Select Demo",
        [
            "🎯 Introduction",
            "1️⃣ Classification & Filtering",
            "2️⃣ Extraction & Sentiment",
            "3️⃣ Aggregation & Similarity",
            "4️⃣ Multimodal Capabilities",
        ],
    )

    st.sidebar.divider()
    st.sidebar.markdown("**Available LLMs:**")
    for llm in AVAILABLE_LLMS:
        st.sidebar.caption(f"• {llm}")

    st.sidebar.divider()
    st.sidebar.caption("Built with Snowflake Cortex AI SQL")

    # Route to demo block
    if demo_block == "🎯 Introduction":
        render_intro()
    elif demo_block == "1️⃣ Classification & Filtering":
        render_demo_1_classification()
    elif demo_block == "2️⃣ Extraction & Sentiment":
        render_demo_2_extraction()
    elif demo_block == "3️⃣ Aggregation & Similarity":
        render_demo_3_aggregation()
    else:
        render_demo_4_multimodal()


def render_intro():
    """Introduction: What are Cortex AI SQL Functions?"""
    st.header("🎯 Introduction to Cortex AI SQL Functions")

    st.markdown("""
    ### What are AI SQL Functions?

    Snowflake Cortex AI SQL functions bring **Frontier LLMs directly into SQL queries**.
    No external APIs, no data movement—all processing stays within Snowflake's security perimeter.

    ### Key Benefits for Compliance

    | Benefit | Description |
    |---------|-------------|
    | **Unified Analytics** | AI + traditional analytics in one platform |
    | **Simplified Pipelines** | No ETL to external ML services |
    | **Native Multimodal** | Text, images, audio in SQL |
    | **Governance** | Existing access controls apply to AI outputs |

    ### Available Functions
    """)

    col1, col2 = st.columns(2)
    with col1:
        st.markdown("""
        **Text Analysis:**
        - `AI_CLASSIFY` – Categorize text
        - `AI_FILTER` – Boolean NL filtering
        - `AI_EXTRACT` – Information extraction
        - `AI_SENTIMENT` – Sentiment scoring
        - `AI_TRANSLATE` – Language translation
        """)
    with col2:
        st.markdown("""
        **Advanced:**
        - `AI_AGG` – Aggregate text across rows
        - `AI_EMBED` – Vector embeddings
        - `AI_SIMILARITY` – Similarity calculations
        - `AI_TRANSCRIBE` – Speech-to-text
        - `AI_COMPLETE` – General LLM completion
        """)

    st.info("📚 [Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)")


def render_demo_1_classification():
    """Demo Block 1: Text Classification & Filtering (15 min)"""
    st.header("1️⃣ Text Classification & Filtering")
    st.markdown("Automatically categorize emails and filter for compliance-relevant content.")

    tab1, tab2, tab3 = st.tabs(["AI_CLASSIFY", "AI_FILTER", "Combined Query"])

    with tab1:
        st.subheader("AI_CLASSIFY: Email Risk Categorization")
        st.markdown("""
        **Zero-shot classification** – no training data required.
        Define your categories, and the model classifies immediately.
        """)

        categories = st.multiselect(
            "Risk Categories:",
            ["insider_trading", "market_manipulation", "data_exfiltration",
             "unauthorized_communication", "clean"],
            default=["insider_trading", "market_manipulation", "clean"],
        )

        sample_email = st.text_area(
            "Sample email content:",
            value="Hey, just heard from my contact at Acme Corp - they're announcing the merger tomorrow before market open. We should load up on shares today.",
            height=100,
        )

        if st.button("Classify", key="classify_btn"):
            sql = f"""
-- Classify email into compliance risk categories
SELECT
    AI_CLASSIFY(
        $${sample_email}$$,
        {categories}
    ) AS risk_classification;
"""
            st.code(sql, language="sql")
            st.success("**Expected output:** insider_trading (high confidence)")

    with tab2:
        st.subheader("AI_FILTER: Natural Language Filtering")
        st.markdown("Ask yes/no questions about content in plain English.")

        filter_question = st.text_input(
            "Filter question:",
            value="Does this mention non-public information?",
        )

        if st.button("Apply Filter", key="filter_btn"):
            sql = f"""
-- Boolean filter using natural language
SELECT email_id, sender, subject,
       AI_FILTER(email_content, '{filter_question}') AS flagged
FROM compliance_emails
WHERE AI_FILTER(email_content, '{filter_question}') = TRUE;
"""
            st.code(sql, language="sql")

    with tab3:
        st.subheader("Combined: Classify + Filter Pipeline")
        sql = """
-- Real-time email monitoring pipeline
SELECT
    email_id,
    sender,
    recipient,
    AI_CLASSIFY(
        email_content,
        ['insider_trading', 'market_manipulation', 'data_exfiltration', 'clean']
    ) AS risk_category,
    AI_FILTER(email_content, 'Does this mention non-public information?') AS material_info_flag,
    AI_FILTER(email_content, 'Are specific trade amounts mentioned?') AS trade_amounts_flag
FROM compliance_emails
WHERE ingestion_timestamp >= CURRENT_TIMESTAMP() - INTERVAL '1 DAY';
"""
        st.code(sql, language="sql")


def render_demo_2_extraction():
    """Demo Block 2: Information Extraction & Sentiment (15 min)"""
    st.header("2️⃣ Information Extraction & Sentiment")
    st.markdown("Extract structured data and analyze emotional tone in communications.")

    tab1, tab2, tab3 = st.tabs(["AI_EXTRACT", "AI_SENTIMENT", "AI_TRANSLATE"])

    with tab1:
        st.subheader("AI_EXTRACT: Entity & Information Extraction")
        st.markdown("Ask specific questions to extract structured information.")

        sample_email = st.text_area(
            "Email content:",
            value="Meeting with Goldman Sachs next Tuesday to discuss the AAPL and MSFT positions. Target price for AAPL is $250 by Q2. John from compliance should be looped in.",
            height=100,
            key="extract_email",
        )

        extraction_questions = [
            "What securities or tickers are mentioned?",
            "Are there any price predictions or targets?",
            "What external parties are referenced?",
            "What dates or timeframes are mentioned?",
        ]

        selected_q = st.selectbox("Extraction question:", extraction_questions)

        if st.button("Extract", key="extract_btn"):
            sql = f"""
-- Extract specific compliance-relevant information
SELECT
    email_id,
    AI_EXTRACT(email_content, '{selected_q}') AS extracted_info
FROM compliance_emails
WHERE compliance_flag = TRUE;
"""
            st.code(sql, language="sql")

    with tab2:
        st.subheader("AI_SENTIMENT: Risk Sentiment Analysis")
        st.markdown("""
        Score sentiment from **-1 (negative)** to **+1 (positive)**.
        Useful for detecting stress, frustration, or aggressive language.
        """)

        sql = """
-- Sentiment analysis across trading communications
SELECT
    trader_id,
    email_date,
    AI_SENTIMENT(email_content) AS sentiment_score,
    CASE
        WHEN AI_SENTIMENT(email_content) < -0.5 THEN 'HIGH RISK'
        WHEN AI_SENTIMENT(email_content) < 0 THEN 'ELEVATED'
        ELSE 'NORMAL'
    END AS risk_level
FROM trading_communications
ORDER BY sentiment_score ASC
LIMIT 20;
"""
        st.code(sql, language="sql")

        st.markdown("**Use case:** Flag traders with consistently negative sentiment for review.")

    with tab3:
        st.subheader("AI_TRANSLATE: International Communications")
        st.markdown("Handle multi-language compliance monitoring.")

        source_text = st.text_area(
            "Non-English email:",
            value="Ich habe vertrauliche Informationen über die bevorstehende Fusion erhalten. Wir sollten schnell handeln.",
            height=80,
        )

        if st.button("Translate & Analyze", key="translate_btn"):
            sql = f"""
-- Translate then analyze international communications
SELECT
    email_id,
    original_language,
    AI_TRANSLATE($${source_text}$$, 'de', 'en') AS translated_content,
    AI_CLASSIFY(
        AI_TRANSLATE($${source_text}$$, 'de', 'en'),
        ['insider_trading', 'market_manipulation', 'clean']
    ) AS risk_category
FROM international_emails;
"""
            st.code(sql, language="sql")
            st.info("💡 Translation: 'I have received confidential information about the upcoming merger. We should act quickly.'")


def render_demo_3_aggregation():
    """Demo Block 3: Aggregation & Similarity (10 min)"""
    st.header("3️⃣ Aggregation & Similarity")
    st.markdown("Analyze patterns across multiple records and find similar communications.")

    tab1, tab2 = st.tabs(["AI_AGG", "AI_SIMILARITY"])

    with tab1:
        st.subheader("AI_AGG: Aggregate Insights Across Groups")
        st.markdown("Summarize themes from multiple records using GROUP BY.")

        sql = """
-- Summarize compliance risks by department
SELECT
    department,
    COUNT(*) AS incident_count,
    AI_AGG(
        incident_description,
        'Summarize the main compliance risks and common themes'
    ) AS risk_summary
FROM compliance_incidents
WHERE incident_date >= CURRENT_DATE() - 90
GROUP BY department
ORDER BY incident_count DESC;
"""
        st.code(sql, language="sql")

        st.markdown("**Use case:** Executive dashboards summarizing risk by business unit.")

    with tab2:
        st.subheader("AI_SIMILARITY: Pattern Detection")
        st.markdown("Find emails similar to known violations using vector embeddings.")

        sql = """
-- Find emails similar to a known insider trading violation
WITH known_violation AS (
    SELECT AI_EMBED(email_content) AS violation_embedding
    FROM historical_violations
    WHERE violation_type = 'insider_trading'
    LIMIT 1
)
SELECT
    e.email_id,
    e.sender,
    e.subject,
    AI_SIMILARITY(AI_EMBED(e.email_content), kv.violation_embedding) AS similarity_score
FROM compliance_emails e
CROSS JOIN known_violation kv
WHERE AI_SIMILARITY(AI_EMBED(e.email_content), kv.violation_embedding) > 0.8
ORDER BY similarity_score DESC
LIMIT 10;
"""
        st.code(sql, language="sql")

        st.markdown("**Use case:** Proactively identify communications matching historical violation patterns.")


def render_demo_4_multimodal():
    """Demo Block 4: Multimodal Capabilities (10 min)"""
    st.header("4️⃣ Multimodal Capabilities")
    st.markdown("Process audio recordings and analyze document images.")

    tab1, tab2 = st.tabs(["AI_TRANSCRIBE", "AI_COMPLETE (Images)"])

    with tab1:
        st.subheader("AI_TRANSCRIBE: Compliance Call Processing")
        st.markdown("Convert recorded calls to text for analysis.")

        sql = """
-- Transcribe and analyze compliance calls
WITH transcribed_calls AS (
    SELECT
        call_id,
        trader_id,
        call_date,
        AI_TRANSCRIBE(audio_file) AS transcript
    FROM recorded_calls
    WHERE call_date >= CURRENT_DATE() - 7
)
SELECT
    call_id,
    trader_id,
    AI_CLASSIFY(
        transcript,
        ['insider_trading', 'market_manipulation', 'clean']
    ) AS risk_category,
    AI_EXTRACT(transcript, 'What securities were discussed?') AS securities_mentioned,
    AI_SENTIMENT(transcript) AS call_sentiment
FROM transcribed_calls;
"""
        st.code(sql, language="sql")

        st.markdown("**Pipeline:** Audio → Transcription → Classification → Risk Scoring")

    with tab2:
        st.subheader("AI_COMPLETE: Document Image Analysis")
        st.markdown("Analyze scanned documents, trade confirmations, and attachments.")

        sql = """
-- Analyze document scans for compliance markers
SELECT
    document_id,
    document_type,
    AI_COMPLETE(
        'claude-3-5-sonnet',
        'Analyze this document for compliance concerns. Identify: 1) Document type, 2) Key parties involved, 3) Any red flags or unusual terms, 4) Recommended actions.',
        document_image  -- Image bytes from stage
    ) AS compliance_analysis
FROM document_scans
WHERE scan_date >= CURRENT_DATE() - 30;
"""
        st.code(sql, language="sql")

        st.markdown("""
        **Supported formats:** Trade confirmations, regulatory filings, email attachments (images)

        **Use case:** Automated review of scanned documents in compliance workflows.
        """)


if __name__ == "__main__":
    main()
