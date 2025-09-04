import streamlit as st
import boto3
import json
import os

# --- Configuration ---
AWS_REGION = st.secrets.get("AWS_REGION")
BEDROCK_KNOWLEDGE_BASE_ID = st.secrets.get("BEDROCK_KNOWLEDGE_BASE_ID")
AWS_ACCESS_KEY_ID = st.secrets.get("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = st.secrets.get("AWS_SECRET_ACCESS_KEY")

if not AWS_REGION:
    st.error("AWS_REGION is not set. Please configure it.")
    st.stop()
if not BEDROCK_KNOWLEDGE_BASE_ID:
    st.error("BEDROCK_KNOWLEDGE_BASE_ID is not set. Please configure it.")
    st.stop()
# if not AWS_ACCESS_KEY_ID or not AWS_SECRET_ACCESS_KEY:
#     st.warning("AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY are not set. For Streamlit Community Cloud, these are usually required for Bedrock access. For AWS-native deployments (e.g., App Runner), consider using IAM roles instead.")

try:
    if AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:
        bedrock_agent_runtime = boto3.client(
            service_name='bedrock-agent-runtime',
            region_name=AWS_REGION,
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY
        )
    else:
        bedrock_agent_runtime = boto3.client(
            service_name='bedrock-agent-runtime',
            region_name=AWS_REGION
        )
except Exception as e:
    st.error(f"Error initializing AWS Bedrock client: {e}. Check credentials/IAM role and region.")
    st.stop()

# --- Page Configuration ---
st.set_page_config(
    page_title="Psychiatry Opioid SOPs Assistant 🧠",
    page_icon="📚",
    layout="centered",
    initial_sidebar_state="auto"
)
# st.markdown("An AI assistant to provide information from the ASAM Opioid Use Disorder guidelines.")

# --- Custom CSS for styling ---
st.markdown(
    """
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    """,
    unsafe_allow_html=True
)

st.markdown("""
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

        body {
            font-family: 'Inter', sans-serif;
            background-color: #f8f9fa;
            font-size: 14px; /* Reduced font size */
        }
        .stApp {
            background-color: #f8f9fa;
            /* Use flexbox for the main app layout to control vertical spacing */
            display: flex;
            flex-direction: column;
            min-height: 100vh; /* Ensure app takes full viewport height */
        }

        /* Adjust Streamlit's main content block to allow for header/footer */
        /* This targets the main content area where your title, intro, and chat go */
        .st-emotion-cache-z5fcl4 { /* This class holds the main content column */
            flex-grow: 1; /* Allow it to grow and take available space */
            display: flex;
            flex-direction: column;
            justify-content: space-between; /* Push input to bottom if space is available */
        }
        .st-emotion-cache-1r6dm7m { /* This often wraps st.container, give it space */
             flex-grow: 1; /* Let the chat container grow */
             display: flex;
             flex-direction: column;
        }


        /* Chat row for avatars and bubbles */
        .chat-row {
            display: flex;
            align-items: flex-start;
            margin-bottom: 10px;
        }
        .user-chat-row {
            justify-content: flex-end;
        }
        .assistant-chat-row {
            justify-content: flex-start;
        }

        /* Avatar styling */
        .avatar {
            width: 35px;
            height: 35px;
            border-radius: 50%;
            margin: 0 10px;
            flex-shrink: 0;
            object-fit: cover;
            border: 1px solid #eee;
            background-color: white;
            padding: 5px;
        }
        .user-avatar {
            order: 2;
        }
        .assistant-avatar {
            order: 1;
        }

        /* General bubble styling */
        .chat-bubble {
            padding: 12px 20px;
            border-radius: 15px;
            width: fit-content;
            max-width: 80%;
            margin-bottom: 0px;
            font-family: 'Inter', sans-serif;
            line-height: 1.5;
            box-shadow: 0 2px 8px rgba(0,0,0,0.04);
            font-size: 1.0em; /* Relative to body font size */
        }
        .assistant-bubble {
            background-color: #e0f2f7;
            margin-right: auto;
            color: #333;
        }
        .user-bubble {
            background-color: #5eb3bb;
            color: white;
            margin-left: auto;
        }

        /* --- STYLES FOR THE ACTUAL SCROLLABLE ST.CONTAINER --- */
        /* This targets the div that Streamlit creates for st.container(height=...) */
        /* Use the .st-emotion-cache- classes as they are often more specific and reliable */
        /* IMPORTANT: Inspect your browser's dev tools to get the EXACT class name
                      for your Streamlit version if this doesn't work.
                      Look for a div directly inside [data-testid="stVerticalBlock"]
                      that has 'overflow-y: auto' in its style. */
        [data-testid="stVerticalBlock"] > div.st-emotion-cache-1r6dm7m { /* Common class for scrollable container */
            padding: 15px;
            border-radius: 10px;
            background-color: #ffffff;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
            /* min-height and max-height are managed by st.container(height=...) */
            /* overflow-y: auto is also managed by st.container(height=...) */
            display: flex;
            flex-direction: column;
            scroll-behavior: smooth; /* Smooth scrolling for new messages */
            margin-top: 30px; /* Adjust margin for spacing below intro text */
            flex-grow: 1; /* Allow this container to take up remaining vertical space */
            overflow-y: auto; /* Explicitly ensure scroll if Streamlit's height doesn't force it */
        }


        /* Style for the chat input container */
        .st-emotion-cache-t2qbtj { /* The container around the chat input (st.chat_input) */
            border-radius: 25px;
            border: 1px solid #dcdcdc;
            padding: 8px 15px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.03);
            background-color: white;
            margin-top: 20px; /* Space above the input box */
        }
        .st-emotion-cache-t2qbtj textarea { /* The actual textarea inside chat input */
            padding: 0px;
            font-size: 14px;
        }

        /* Style for the send button */
        .stButton button {
            border-radius: 25px;
            background-color: #5eb3bb;
            color: white;
            padding: 10px 25px;
            border: none;
            font-weight: bold;
            cursor: pointer;
            transition: background-color 0.3s ease;
        }
        .stButton button:hover {
            background-color: #4a9fa7;
        }

        /* Source Attributions */
        .source-attributions {
            font-size: 0.75em; /* Slightly smaller than main text */
            color: #666;
            margin-top: 15px;
            padding-top: 10px;
            border-top: 1px dashed #e0e0e0;
            white-space: pre-wrap;
        }
        .source-attributions a {
            color: #5eb3bb;
            text-decoration: none;
        }
        .source-attributions a:hover {
            text-decoration: underline;
        }

        /* Responsive adjustments */
        @media (max-width: 768px) {
            .chat-bubble {
                max-width: 90%;
                padding: 10px 15px;
            }
            .avatar {
                width: 30px;
                height: 30px;
            }
        }
    </style>
""", unsafe_allow_html=True)

# --- Title and Introduction (Fixed at Top) ---
st.title("Psychiatry Opioid SOPs Assistant")
# st.markdown("An AI assistant to provide information from the ASAM Opioid Use Disorder guidelines.")
# st.title("🧠 Psychiatric SOP Assistant")
st.markdown("---")
st.write(
    """
    Welcome! This assistant is designed to help you quickly navigate and 
    find information from the ASAM National Practice Guideline for the Treatment 
    of Opioid Use Disorder.
    """
)

st.markdown("---")

# --- 2. Include about three questions for new users. ---
st.markdown("##### Example Questions:")
st.info(
    """
    * What are the three primary medications for Opioid Use Disorder?
    * What is the ASAM definition of addiction?
    * What is the recommended approach for individuals in the criminal justice system with opioid use disorder?
    """
)

st.markdown("---")
st.write("")

# Initialize chat history in session state
if "messages" not in st.session_state:
    st.session_state.messages = []
    st.session_state.messages.append({"role": "assistant", "content": "Please type your question below!"})

# --- Chat Display Area (Scrollable) ---
# Create the Streamlit container that will hold the chat messages
# Use a high height to ensure it takes most vertical space, forcing its *own* scroll
chat_messages_container = st.container(height=600, border=False) # Increased height to ensure its own scroll

# Display chat messages from history inside the Streamlit container
with chat_messages_container:
    for message in st.session_state.messages:
        if message["role"] == "user":
            st.markdown(f'''
                <div class="chat-row user-chat-row">
                    <div class="chat-bubble user-bubble">{message["content"]}</div>
                    <img class="avatar user-avatar" src="https://api.iconify.design/ph/person-fill.svg" alt="User Avatar">
                </div>
            ''', unsafe_allow_html=True)
        else:
            st.markdown(f'''
                <div class="chat-row assistant-chat-row">
                    <img class="avatar assistant-avatar" src="https://api.iconify.design/fluent/brain-circuit-20-filled.svg" alt="Assistant Avatar">
                    <div class="chat-bubble assistant-bubble">{message["content"]}</div>
                </div>
            ''', unsafe_allow_html=True)

# --- User Input and RAG Interaction (Fixed at Bottom) ---
# Use st.chat_input for a more integrated chat experience
user_prompt = st.chat_input("Ask a question about SOPs...")

if user_prompt:
    # Add user message to chat history
    st.session_state.messages.append({"role": "user", "content": user_prompt})

    # Process the LLM response immediately after adding user message
    with st.spinner("Searching SOPs..."):
        try:
            # A prompt template is defined to set the persona and rules for the AI.
            PROMPT_TEMPLATE = """
            Human: You are an internal AI system that assists with standard operating procedures (SOPs) for opioid treatment in the field of psychiatry. Your answers must be based exclusively on the provided ASAM National Practice Guideline for the Treatment of Opioid Use Disorder documents.
            Use the following pieces of information to provide a concise answer to the question enclosed in <question> tags. 
            If you don't know the answer, just say that you don't know, don't try to make up an answer.
            <context>
            $search_results$
            </context>

            <question>
            $input_text$
            </question>

            The response should be specific and use clinical guidance, statistics, or numbers when possible, as found in the guidelines.

            Assistant:"""
                
            response = bedrock_agent_runtime.retrieve_and_generate(
                    input={
                        'text': user_prompt
                    },
                    retrieveAndGenerateConfiguration={
                        'type': 'KNOWLEDGE_BASE',
                        'knowledgeBaseConfiguration': {
                            'knowledgeBaseId': BEDROCK_KNOWLEDGE_BASE_ID,
                            # The modelArn is now part of the prompt configuration
                            # and the prompt template is specified here.
                            'retrievalConfiguration': {
                                'vectorSearchConfiguration': {'numberOfResults': 4}
                            },
                            'generationConfiguration': {
                                'promptTemplate': {
                                    'textPromptTemplate': PROMPT_TEMPLATE
                                }
                            },
                            'modelArn': f"arn:aws:bedrock:{AWS_REGION}::foundation-model/amazon.nova-micro-v1:0" 
                        }
                    }
                )
            assistant_response = response['output']['text']
            st.session_state.messages.append({"role": "assistant", "content": assistant_response})

        except Exception as e:
            error_message = f"I apologize, an error occurred while processing your request: {e}. Please try again."
            st.error(error_message)
            st.session_state.messages.append({"role": "assistant", "content": error_message})
    
    # After processing and adding assistant message, rerun to display the new messages
    # and trigger the scroll-to-bottom JavaScript.
    st.rerun()

st.markdown("---")
st.caption("Powered by AWS Bedrock Knowledge Bases and Streamlit.")

# JavaScript to scroll to the bottom after the chat history updates
# This targets the actual scrollable div created by st.container(height=...)
st.markdown("""
<script>
    // This targets the specific div that has the `overflow: auto` style,
    // which is typically the inner div of st.container(height=...).
    // The class 'st-emotion-cache-1r6dm7m' is common, but may vary by Streamlit version.
    // Inspect with browser dev tools (F12) to confirm if this doesn't work.
    const scrollableDiv = document.querySelector('[data-testid="stVerticalBlock"] > div.st-emotion-cache-1r6dm7m');
    if (scrollableDiv) {
        scrollableDiv.scrollTop = scrollableDiv.scrollHeight;
    }
</script>
""", unsafe_allow_html=True)