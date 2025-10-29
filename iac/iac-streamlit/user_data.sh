#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# Update the system and install necessary packages
sudo yum update -y
sudo yum install -y git python3-pip

# Switch to the ec2-user to manage files and permissions correctly
sudo -u ec2-user -i <<'EOF'
# Clone the repository
git clone https://github.com/tidika/psych-ai-assistant.git
cd psych-ai-assistant/frontend

# Setup Python virtual environment
python3 -m venv my_streamlit_env
source my_streamlit_env/bin/activate
pip install -r requirements.txt

# Create the .streamlit directory with only the region and knowledge base ID
mkdir -p /home/ec2-user/.streamlit
cat <<'EOM' > /home/ec2-user/.streamlit/secrets.toml
# .streamlit/secrets.toml
# AWS Configuration
AWS_REGION = "us-east-1"
BEDROCK_KNOWLEDGE_BASE_ID = "KXI93EOMDV"
EOM

# Run the Streamlit application
streamlit run app.py
EOF