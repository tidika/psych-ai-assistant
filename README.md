# Psych-AI-Assistant
*A secure, compliant Retrieval-Augmented Generation (RAG) solution for psychiatry SOPs built on AWS*


## Project Overview
Psych-AI Assistant is a purpose-built AI system designed to help clinicians quickly retrieve, interpret, and act on standard operating procedures (SOPs) in psychiatry. Leveraging RAG (Retrieval-Augmented Generation) and modern AWS services, it offers:

* A vector-searchable knowledge base built from psychiatry SOP documents

* A secure, private architecture ensuring no PHI/PII exposure

* Responsive and compliant AI-driven answers for SOP queries

In essence, it bridges AI and healthcare best practices – helping professionals access critical SOP guidance while adhering to strict regulatory frameworks.



## Motivation
In regulated domains such as healthcare, building AI systems is not only about accuracy or speed — trust, privacy, and compliance matter just as much. When I developed this assistant for Psychiatry SOPs, the big question was:

   *How do you build a functional RAG system and ensure it meets HIPAA-level safeguards?*

This project captures the architectural, operational, and procedural lessons learned while implementing a **HIPAA-compliant RAG system on AWS** — making it a blueprint for other engineers working in privacy-sensitive domains.


## Key Features

* **Secure network isolation:** Private VPC with public & private subnets, NAT gateway, AWS VPC endpoints for S3, Bedrock, Pinecone, etc.

* **Encryption everywhere:** Data encrypted at rest (S3, vector store) and in transit (HTTPS/TLS via ACM).

* **Audit and observability:** Full AWS CloudTrail coverage + CloudWatch alarms for unauthorized access or configuration changes.

* **Fine-grained access control:** Authentication via AWS Cognito, IAM roles enforcing least-privilege access.

* **PII/PHI guardrails:**  Pre-embedding redaction of sensitive identifiers; filtering model outputs to avoid exposure of patient information.

* **Retrieval-Augmented Generation workflow:** Documents → embeddings → vector store → LLM (via AWS Bedrock) → clinically-oriented answer generation.



## System Architecture  & Design
![System Architecture](/images/system_architecture.png)
### High - Level Workflow

*  Document ingestion (psychiatry SOPs) into S3

*  Redaction of PII/PHI during preprocessing

* Embedding generation and storage in vector database (e.g., Pinecone via PrivateLink)

* Front-end app in a private subnet serving clinician queries

*  RAG pipeline: query → retrieval → LLM answer → post-filter for guardrails

* Monitoring and audit logs captured via CloudTrail & CloudWatch


## RAG Design
The Retrieval-Augmented Generation (RAG) pipeline is designed to securely process, embed, and retrieve psychiatry SOP documents within a HIPAA-compliant AWS environment.

![RAG Architecture](/images/rag_architecture.png)

Workflow Overview

1. **Document Ingestion:** Clinicians or administrators upload SOP documents to a secure Amazon S3 bucket.
This upload triggers an AWS Lambda function, which retrieves the new data and processes it for indexing.

2. **Embedding Generation:** he Lambda function invokes a custom Python script that parses and chunks the document text, generating vector embeddings using a Bedrock embedding model.
These embeddings are stored in a Pinecone vector database for efficient similarity search.

3. **Knowledge Base Sync:** Processed data are synchronized with a Bedrock Knowledge Base, allowing seamless retrieval of relevant context during inference.

4. **User Query & Retrieval:** When a user submits a query through the front-end, the backend—running on an EC2 instance with LangChain—queries Pinecone for the most relevant document chunks.

5. **Response Generation:** The retrieved chunks, along with the user query, are passed to an LLM (Nova Micro) hosted on Amazon Bedrock.The model then generates a context-aware, coherent response, which is returned to the user.

## Working App. 

