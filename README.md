# CERBot: Experimental Classification Results and Demonstration Videos

## Overview
This repository provides supplementary material associated with the research work on **CERBot**, an LLM-based conversational agent designed to support the management and operation of Renewable Energy Communities (RECs).
The proposed framework combines deterministic, rule-based software components with Large Language Models (LLMs) to provide natural language interaction, intent classification, and integration with Energy Management System (EMS) functionalities.
The repository makes available experimental datasets, classification results, MATLAB analysis scripts, and demonstration videos supporting the evaluation of the proposed architecture.

## Repository Contents
### 1. Classification Experiments
The `Classification Test.zip` archive contains the experimental material used to assess different intent classification architectures and configurations.
Its contents include:
- **Classification datasets:** Excel files containing labeled messages generated using ChatGPT, Claude, DeepSeek, and Grok, together with a separate human dataset file.
- **Experimental results:** MATLAB `.mat` files containing the outputs of classification experiments under different classifier configurations.
- **Performance evaluation:** MATLAB scripts for processing the experimental results and evaluating classification metrics, including confusion matrices.
- **Previous results:** Archived experimental results retained for reference and comparison.

The four AI-generated datasets each contain 950 labeled messages, allowing classification performance to be evaluated across different sources of natural language requests.
The experimental configurations explore alternative classification strategies, including local, LLM-based, and hybrid approaches, with different models and inference settings.

### 2. Demonstration Videos
Two demonstration videos accompany the experimental material to illustrate the operation of the CERBot framework and its interaction with the developed web interface.
The videos are distributed as GitHub Release assets rather than directly within the repository to avoid unnecessary storage overhead.

**Demonstration 1: Cerbot controllable loads example**
In the user workflow, a request to activate automatic load scheduling is mapped to AUTO_PLANNING_ON; the corresponding shared-variable command is issued, the deterministic EMS enables the service, and the chatbot returns confirmation. The sequence verifies the path from free-form language to supervisory execution and user feedback.

**Demonstration 2: Cerbot admin broadcast example**
In the administrator workflow, broadcast content is routed to the dedicated branch, reformulated, confirmed by the administrator, and propagated to registered users. This validates context-dependent routing and multi-user communication while preserving the separation between LLM reasoning and EMS control.

The videos and classification archive are available in the [Releases](../../releases) section.

## Classification Evaluation
The experimental evaluation focuses on the performance of different intent classification strategies.
The available material supports the analysis of:
- Classification accuracy and class-specific performance.
- Precision, recall, specificity, and F1-score.
- Confusion matrices and misclassification patterns.
- Processing latency.
- Token consumption and computational cost.

The results allow the comparison of different architectural configurations and support the assessment of the trade-off between classification performance and resource requirements.

## Data Analysis
The supplied MATLAB scripts can be used to inspect and process the experimental results.

The main analysis files include:
- `Classification_Dataset_Setup.m`: loads the selected classification dataset.
- `Test_Result_Elaboration.m`: processes the classification outputs and associated performance data.
- `Test_Result_Elaboration_with_cache.m`: provides an alternative analysis workflow accounting for token caching.
- `Test_Result_Elaboration_Haiku_Combined.m`: processes additional experimental configurations.
- `evaluateClassifierConfusionMatrix.m`: supports the evaluation of classification confusion matrices.
The scripts rely on the provided experimental files and their expected directory structure. They are supplied for analysis and inspection and do not constitute a standalone implementation of the complete CERBot framework.

## Web Application
A web-based interface has been developed to demonstrate the interaction between the conversational agent, REC participants, and the energy management environment.

**CERBot Web Interface:** [https://synoptic-flow-home.lovable.app/](https://synoptic-flow-home.lovable.app/)
The interface provides a practical demonstration environment for the functionalities discussed in the associated research.

## Availability and Scope
This repository is intended as a supplementary scientific resource.
It provides access to the classification datasets, experimental results, analysis scripts, and demonstration material.
The complete operational source code of the CERBot framework and its external service integrations is not included in this release.

## Associated Publication
Selective Deterministic Gating for LLM-Based Supervisory Agents in Renewable Energy Communities
Authors: Lorenzo Becchi, Marco Bindi, Matteo Intravaia, Gabriele Maria Lozito, Maria Cristina Piccirilli, Riccardo Marconi and Vittoria Cacciavillani
Journal: [placeholder]
DOI: [placeholder]

## Citation
If you use the datasets or experimental material provided in this repository, please cite the associated publication.

## Contact
For questions regarding the experimental material or the research framework, please contact the corresponding author of the associated publication.
