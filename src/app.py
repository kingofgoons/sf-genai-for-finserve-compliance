"""
Snowflake GenAI for Financial Services Compliance
Main Streamlit application demonstrating Cortex AI capabilities.
"""

import streamlit as st
from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session

# Page config
st.set_page_config(
    page_title="GenAI Compliance Demo",
    page_icon="🏦",
    layout="wide",
)


def get_session() -> Session:
    """Get Snowflake session - works in SiS or local dev."""
    try:
        return get_active_session()
    except Exception:
        # Local development: use connection params
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
    st.markdown("Demonstrate Snowflake Cortex AI for compliance workflows.")

    # Sidebar
    st.sidebar.header("Configuration")
    demo_mode = st.sidebar.selectbox(
        "Select Demo",
        [
            "Document Summarization",
            "Policy Extraction",
            "Risk Classification",
            "Q&A with Compliance Docs",
        ],
    )

    st.sidebar.divider()
    st.sidebar.caption("Built with Snowflake Cortex AI")

    # Main content area
    if demo_mode == "Document Summarization":
        render_summarization_demo()
    elif demo_mode == "Policy Extraction":
        render_extraction_demo()
    elif demo_mode == "Risk Classification":
        render_classification_demo()
    else:
        render_qa_demo()


def render_summarization_demo():
    """Demo: Summarize compliance documents using Cortex."""
    st.header("📄 Document Summarization")
    st.markdown("Use `SNOWFLAKE.CORTEX.SUMMARIZE` to condense lengthy compliance documents.")

    sample_text = st.text_area(
        "Paste compliance document text:",
        height=200,
        placeholder="Enter or paste a compliance policy, regulation excerpt, or audit finding...",
    )

    if st.button("Summarize", type="primary") and sample_text:
        with st.spinner("Generating summary..."):
            # Cortex summarization query
            # Demo: shows the SQL that would run
            sql = f"""
            -- Summarize compliance document using Cortex AI
            SELECT SNOWFLAKE.CORTEX.SUMMARIZE($${sample_text}$$) AS summary;
            """
            st.code(sql, language="sql")
            st.info("💡 Connect to Snowflake to execute this query.")


def render_extraction_demo():
    """Demo: Extract key policy elements."""
    st.header("🔍 Policy Extraction")
    st.markdown("Use `SNOWFLAKE.CORTEX.COMPLETE` to extract structured data from policies.")

    sample_policy = st.text_area(
        "Paste policy text:",
        height=200,
        placeholder="Enter a compliance policy to extract key requirements...",
    )

    if st.button("Extract Requirements", type="primary") and sample_policy:
        prompt = f"""Extract the following from this compliance policy:
1. Key requirements (as bullet points)
2. Affected departments
3. Compliance deadline (if mentioned)
4. Penalties for non-compliance (if mentioned)

Policy:
{sample_policy}"""

        sql = f"""
        -- Extract structured info from policy using Cortex AI
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            $${prompt}$$
        ) AS extracted_info;
        """
        st.code(sql, language="sql")
        st.info("💡 Connect to Snowflake to execute this query.")


def render_classification_demo():
    """Demo: Classify risk levels."""
    st.header("⚠️ Risk Classification")
    st.markdown("Use `SNOWFLAKE.CORTEX.CLASSIFY_TEXT` for risk categorization.")

    finding = st.text_area(
        "Enter audit finding or incident:",
        height=150,
        placeholder="Describe an audit finding or compliance incident...",
    )

    categories = ["Critical", "High", "Medium", "Low", "Informational"]

    if st.button("Classify Risk", type="primary") and finding:
        sql = f"""
        -- Classify risk level using Cortex AI
        SELECT SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
            $${finding}$$,
            {categories}
        ) AS risk_classification;
        """
        st.code(sql, language="sql")
        st.info("💡 Connect to Snowflake to execute this query.")


def render_qa_demo():
    """Demo: Q&A over compliance documents."""
    st.header("💬 Q&A with Compliance Docs")
    st.markdown("Use Cortex Search or RAG patterns for compliance Q&A.")

    question = st.text_input(
        "Ask a compliance question:",
        placeholder="e.g., What are the data retention requirements for PII?",
    )

    if st.button("Get Answer", type="primary") and question:
        sql = f"""
        -- RAG pattern: retrieve relevant docs then answer with Cortex
        WITH relevant_docs AS (
            SELECT content, 
                   VECTOR_COSINE_SIMILARITY(embedding, 
                       SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', $${question}$$)
                   ) AS similarity
            FROM compliance_docs
            ORDER BY similarity DESC
            LIMIT 5
        )
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            CONCAT('Based on these compliance documents: ', 
                   LISTAGG(content, ' '), 
                   ' Answer this question: {question}')
        ) AS answer
        FROM relevant_docs;
        """
        st.code(sql, language="sql")
        st.info("💡 Connect to Snowflake to execute this query.")


if __name__ == "__main__":
    main()

