import streamlit as st
import boto3


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

# --- Initialize Bedrock Client ---
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
    st.error(f"Error initializing AWS Bedrock client: {e}. Check IAM role and region.")
    st.stop()

# --- Session State Management ---
if "start_chat" not in st.session_state:
    st.session_state.start_chat = False
if "messages" not in st.session_state:
    st.session_state.messages = []

# --- Page Configuration ---
st.set_page_config(
    page_title="Psychiatry Opioid SOPs Assistant 🧠",
    page_icon="📚",
    layout="centered",
    initial_sidebar_state="auto"
)

# --- UI Elements ---
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

# --- Example Questions ---
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
    st.session_state.messages = [{"role": "assistant", "content": "Please type your question below!"}]

if st.button("Exit Chat"):
    st.session_state.messages = []
    st.session_state.start_chat = False

# --- Chat Logic ---
if st.session_state.start_chat:
    # Display chat messages from history on app rerun
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Accept user input
    if prompt := st.chat_input("Ask a question about SOPs..."):
        # Add user message to chat history
        st.session_state.messages.append({"role": "user", "content": prompt})
        # Display user message in chat message container
        with st.chat_message("user"):
            st.markdown(prompt)

        # Process the LLM response
        with st.spinner("Searching SOPs..."):
            try:
                # Prompt template for Bedrock
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
                        'text': prompt
                    },
                    retrieveAndGenerateConfiguration={
                        'type': 'KNOWLEDGE_BASE',
                        'knowledgeBaseConfiguration': {
                            'knowledgeBaseId': BEDROCK_KNOWLEDGE_BASE_ID,
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
        
        # Display assistant response in chat message container
        with st.chat_message("assistant"):
            st.markdown(st.session_state.messages[-1]["content"])

else:
    st.write("Click 'Start Chat' to begin.")

st.markdown("---")
st.caption("Powered by AWS Bedrock Knowledge Bases and Streamlit.")