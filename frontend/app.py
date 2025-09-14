import os
import boto3
import streamlit as st
from langchain_aws import ChatBedrock
from langchain_community.retrievers import AmazonKnowledgeBasesRetriever
from langchain.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough, RunnableParallel


# --- Configuration ---
AWS_REGION = st.secrets.get("AWS_REGION")
BEDROCK_KNOWLEDGE_BASE_ID = st.secrets.get("BEDROCK_KNOWLEDGE_BASE_ID")
AWS_ACCESS_KEY_ID = st.secrets.get("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = st.secrets.get("AWS_SECRET_ACCESS_KEY")

if not AWS_REGION or not BEDROCK_KNOWLEDGE_BASE_ID:
    st.error("AWS_REGION or BEDROCK_KNOWLEDGE_BASE_ID is not set. Please configure it.")
    st.stop()


# --- Initialize Clients and Chains ---
@st.cache_resource
def initialize_resources():
    """Initializes and caches the Bedrock clients and LangChain components."""
    try:
        if AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:
            # Set environment variables for authentication for both boto3 and LangChain
            os.environ["AWS_ACCESS_KEY_ID"] = AWS_ACCESS_KEY_ID
            os.environ["AWS_SECRET_ACCESS_KEY"] = AWS_SECRET_ACCESS_KEY
            os.environ["AWS_DEFAULT_REGION"] = AWS_REGION

            bedrock_client = boto3.client(
                service_name="bedrock-runtime",
                region_name=AWS_REGION,
                aws_access_key_id=AWS_ACCESS_KEY_ID,
                aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            )
                 # Client for retrieving information from knowledge bases (used by the retriever)
            bedrock_agent_runtime_client = boto3.client(
            service_name="bedrock-agent-runtime",
            region_name=AWS_REGION,
        )

        else:
            bedrock_client = boto3.client(
                service_name="bedrock-runtime", region_name=AWS_REGION
            )
            # Client for retrieving information from knowledge bases (used by the retriever)
            bedrock_agent_runtime_client = boto3.client(
            service_name="bedrock-agent-runtime",
            region_name=AWS_REGION,
        )


        # Initialize LLM and Retriever
        modelId = "amazon.nova-micro-v1:0"
        llm = ChatBedrock(model_id=modelId, client=bedrock_client)
        retriever = AmazonKnowledgeBasesRetriever(
            knowledge_base_id=BEDROCK_KNOWLEDGE_BASE_ID,
            retrieval_config={"vectorSearchConfiguration": {"numberOfResults": 3}},
            client=bedrock_agent_runtime_client,
        )

        return llm, retriever
    except Exception as e:
        st.error(
            f"Error initializing AWS Bedrock client: {e}. Check IAM role and region."
        )
        st.stop()


# Define the prompt template
PROMPT_TEMPLATE = """
Human: You are an internal AI system that assists with standard operating procedures (SOPs) for opioid treatment in the field of psychiatry. Your answers must be based exclusively on the provided ASAM National Practice Guideline for the Treatment of Opioid Use Disorder documents.
Use the following pieces of information to provide a concise answer to the question enclosed in <question> tags. 
If you don't know the answer, just say that you don't know, don't try to make up an answer.
<context>
{context}
</context>

<question>
{question}
</question>

The response should be specific and use clinical guidance, statistics, or numbers when possible, as found in the guidelines.

Assistant:"""
prompt_template = PromptTemplate(
    template=PROMPT_TEMPLATE, input_variables=["context", "question"]
)


# Define the formatting functions
def format_docs(docs):
    return "\n\n".join(doc.page_content for doc in docs)


def format_citations(docs):
    citations = []
    unique_sources = set()
    for doc in docs:
        source_uri = doc.metadata.get("source_metadata", {}).get(
            "x-amz-bedrock-kb-source-uri"
        )
        page_number = doc.metadata.get("source_metadata", {}).get(
            "x-amz-bedrock-kb-document-page-number"
        )
        if source_uri and page_number:
            filename = source_uri.split("/")[-1]
            source_key = f"{filename}-{page_number}"
            if source_key not in unique_sources:
                # Use a specific format for each citation entry with correct indentation and newlines
                citations.append(
                    f"**Reference {len(unique_sources) + 1}:**"
                    f"  \n**Source Document:** {filename}"
                    f"  \n**Page Number:** {page_number}"
                )
                unique_sources.add(source_key)

    if not citations:
        return "No specific citations found."

    # Join the formatted citation entries with a double newline for a blank line
    # between each reference.
    formatted_citations = "\n\n".join(citations)

    # Return the full string with the header as a bolded, normal-sized line
    return f"\n\n**----------------------------------Retrieved References------------------------------**\n\n{formatted_citations}\n"


# --- Session State Management ---
if "start_chat" not in st.session_state:
    st.session_state.start_chat = False
if "messages" not in st.session_state:
    st.session_state.messages = []

# --- Streamlit App ---
st.set_page_config(
    page_title="Psychiatry Opioid SOPs Assistant 🧠",
    page_icon="📚",
    layout="centered",
    initial_sidebar_state="auto",
)

st.title("Psychiatry Opioid SOPs Assistant")
st.markdown("---")
st.write(
    """
    Welcome! This assistant is designed to help you quickly navigate and 
    find information from the ASAM National Practice Guideline for the Treatment 
    of Opioid Use Disorder.
    """
)
st.markdown("---")

# Example Questions
st.markdown("##### Example Questions:")
st.info(
    """
    * What are the three primary medications for Opioid Use Disorder?
    * What is the ASAM definition of addiction?
    * What is the recommended approach for individuals in the criminal justice system with opioid use disorder?
    """
)
st.markdown("---")

# Start/Exit Chat Buttons
if st.sidebar.button("Start Chat"):
    st.session_state.start_chat = True
    st.session_state.messages = [
        {"role": "assistant", "content": "Please type your question below!"}
    ]

if st.button("Exit Chat"):
    st.session_state.messages = []
    st.session_state.start_chat = False

# Chat Logic
if st.session_state.start_chat:
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    if prompt := st.chat_input("Ask a question about SOPs..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.spinner("Searching SOPs..."):
            try:
                llm, retriever = initialize_resources()

                # Create the core RAG chain once
                rag_chain = (
                    RunnableParallel(
                        {
                            "context": retriever | format_docs,
                            "question": RunnablePassthrough(),
                        }
                    )
                    | prompt_template
                    | llm
                    | StrOutputParser()
                )

                # Get the final answer from the core chain
                answer = rag_chain.invoke(prompt)

                # Get the retrieved documents for citations (separate call)
                retrieved_docs = retriever.invoke(prompt)

                # Format the citations
                formatted_citations = format_citations(retrieved_docs)

                # Combine the answer and citations into a single markdown string
                assistant_response = answer + formatted_citations

                # Append the combined string to the chat messages
                st.session_state.messages.append(
                    {"role": "assistant", "content": assistant_response}
                )

            except Exception as e:
                error_message = f"I apologize, an error occurred while processing your request: {e}. Please try again."
                st.error(error_message)
                st.session_state.messages.append(
                    {"role": "assistant", "content": error_message}
                )

        with st.chat_message("assistant"):
            st.markdown(st.session_state.messages[-1]["content"])

else:
    st.write("Click 'Start Chat' to begin.")

st.markdown("---")
st.caption("Powered by AWS Bedrock Knowledge Bases and Streamlit.")
