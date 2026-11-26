# CERBot: Experimental Classification Results and Demonstration Videos

## Overview

This repository provides supplementary material for **CERBot**, a conversational supervisory agent for Renewable Energy Communities (RECs). The framework combines deterministic rules and Large Language Models (LLMs) to route natural-language requests to Energy Management System (EMS) services.

The research evaluates **accuracy–resource trade-offs between classification architectures using the same LLM**, including selective deterministic gating (HS-Single) and single-stage LLM classification (Single). It does not assume that the hybrid architecture must outperform Single in accuracy.

## Repository Contents

| Path | Material |
| --- | --- |
| `datasets/` | Four synthetic Italian intent-classification datasets. |
| `source/` | Agent definitions, deterministic classifiers, preprocessing, route mapping, batch configurations, provider adapters and local baselines. |
| `prompts/` | Readable versions of the six CERBot classification prompts. |
| `analysis/` | MATLAB result elaboration and confusion-matrix evaluation. |
| `results/` | Per-run and per-message exports, pooled external results and separate baseline cross-validation outputs. |
| `config/` | Credential-file example containing placeholders only. |
| `docs/` | Experimental protocol, execution dependencies, release notes, provenance and validation checks. |
| `Classification Test.zip` | Previously published archive containing datasets, raw experimental outputs, earlier analysis scripts and historical configurations. |

The historical archive and previous release are retained for reference. Their contents do not imply that every archived configuration is included in the paper tables.

## Datasets and Classification Evaluation

The benchmark includes four datasets generated using **ChatGPT, Claude, Grok and DeepSeek**. All evaluated messages are in Italian. Each dataset contains **950 messages across 19 target intents**, with 50 examples per intent.

The ChatGPT dataset is used for development, local-baseline training and trusted-set definition. Claude, Grok and DeepSeek provide external cross-generator test sets, pooled into 2,850 messages when all three are available for a configuration. The reported benchmark uses synthetic data; no human-labelled validation corpus is included in the reported evaluation.

The recorded results support analysis of accuracy, precision, recall, specificity, F1-score, confusion matrices, workflow latency and token usage. API cost estimates concern classifier tokens under the pricing assumptions documented in the paper. Cross-generator testing evaluates variation between synthetic corpora, not real-user field performance.

## Classification Sources and Local Baselines

The source files document the hierarchical, Single, H-Single and HS-Single routing strategies. The batch runner contains the fixed trusted set and the logic that accepts complete trusted local routes or delegates the original message to Single.

Two supervised local baselines are also provided:

- **Lexical baseline:** word unigram/bigram and character 3–5 gram Term Frequency–Inverse Document Frequency features with multinomial logistic regression.
- **Semantic baseline:** frozen, normalized 384-dimensional embeddings from `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`, followed by multinomial logistic regression.

Both are trained only on the ChatGPT development set. Development performance is estimated using five-fold stratified group cross-validation, with identical normalized messages assigned to the same fold. Final fitted models are evaluated on the external datasets without further adaptation.

| Baseline | ChatGPT out-of-fold accuracy |
| --- | ---: |
| TF-IDF + logistic regression | 70.63% |
| MiniLM + logistic regression | 83.68% |

The OOF predictions and scores are in `results/baseline_validation/`. **ChatGPT predictions from the final fitted models in the batch exports are training-set evaluations, not cross-validation results.**

Fitted classifiers, training/inference code and environment metadata are supplied in `source/baselines/`. The pretrained encoder weights are retrieved separately using the included `fetch_encoder.py`, at the revision recorded in the metadata. See [execution dependencies](docs/DEPENDENCIES.md) for setup details.

## Data Analysis

The main current MATLAB files are:

- `analysis/Classification_Dataset_Setup.m`: loads the selected Excel dataset and applies the benchmark role prefix.
- `analysis/Test_Result_Elaboration_1120.m`: processes individual runs and aggregates external datasets separately for each model, effort and architecture.
- `analysis/evaluateClassifierConfusionMatrix.m`: computes classification metrics and generates confusion matrices with consistent class ordering, enlarged text and SVG/PDF/600-dpi PNG export.

To inspect saved summaries from the repository root:

```matlab
Summary = readtable(fullfile('results', 'Classification_summary_Test.csv'));
External = readtable(fullfile('results', 'Combined_External_Test_summary.csv'));
```

The complete message-level export is distributed as `results/Classification_records_Test.csv.gz`. It can be decompressed with MATLAB `gunzip`. Use the `Macro_*_19` summary columns for macro metrics over the 19 benchmark target intents. Inspecting the recorded results does not require API calls.

Raw-run elaboration requires the matching `.mat` files from the historical archive or the original experiment folders. The eight added baseline batch runs are supplied in the consolidated exports; their separate conversation-state files are not included in the historical archive. Adjust `Classificator_list` to the raw runs available locally. For normalized numeric plots of the external aggregates, set `Combined_plot_ON = [0 1 0 0]` in the elaboration script.

## Demonstration Videos

Two functional demonstrations remain available as assets of the [existing release](https://github.com/TheBeccaccino/AI-Agent-for-Renewable-Energy-Communities/releases/tag/v1.0-CERbot-supplementary):

1. **User load-planning workflow:** a natural-language request is classified as `AUTO_PLANNING_ON`, passed to the deterministic EMS and followed by a confirmation.
2. **Administrator broadcast workflow:** a communication is routed to the broadcast branch, reformulated and confirmed before distribution to community members.

Both recordings show the conversational web interface alongside the MATLAB environment, allowing workflow states and shared-variable updates to be observed. These demonstrations illustrate end-to-end functionality and are separate from the statistical classification benchmark.

## Web Application

The [CERBot Web Interface](https://synoptic-flow-home.lovable.app/) provides the demonstration environment used for the workflows described in the associated research.

## Availability and Scope

This repository is a supplementary scientific resource. It includes classification sources and recorded results, but not a standalone installation of the complete operational CERBot/EMS platform. Project-specific paths, remaining original helpers and simulator resources are documented in [DEPENDENCIES.md](docs/DEPENDENCIES.md).

The complete runtime credential file must remain local. `config/LLM_API_KEYS.example.txt` contains placeholders only. The current loader requires both provider variables to be present and non-empty.

The benchmark evaluates known intents using single-message inputs. Human-authored field validation, adversarial-security testing, unknown-intent rejection and history-dependent dialogue evaluation require separate studies.

## Associated Publication

**Selective Deterministic Gating for LLM-Based Supervisory Agents in Renewable Energy Communities**

Lorenzo Becchi, Marco Bindi, Matteo Intravaia, Gabriele Maria Lozito, Maria Cristina Piccirilli, Riccardo Marconi and Vittoria Cacciavillani.

Publication details and the article DOI will be added when available.

## Citation

Citation metadata are provided in [CITATION.cff](CITATION.cff). When using these materials, cite the specific archived release used in the analysis and the associated publication when available.

The Zenodo DOI will be added after the revised release has been archived. The release DOI identifies the supplementary materials and is distinct from the article DOI.

## Contact

For questions about the experimental material or research framework, please contact the corresponding author of the associated publication.
