# Dependencies and completeness

This is an archival source/data supplement. Missing original functions have not been recreated. An included source file is not a claim that the full remote benchmark can be executed from this repository alone.

## Included classification code

The five deterministic classifiers and `normalizeMessage` are included. The batch itself contains `Try_Local_Full_Tree`, `Try_Local_Selective_Tree`, `Get_Final_Route_Label` and `Is_Resolved_Local_Label`. The agent definitions, model resolver, architecture setup, dataset setup and Single mapper are included. The six readable prompts are derived from the supplied agent definitions, not independently rewritten prompts.

`LLM_Interaction` calls the included OpenAI/Claude adapters. The OpenAI adapter calls `OpenAIPostResponse_2`, `OpenAIGetResponse` and `GPT_header_generation_new`. The Claude adapter calls `ClaudePostMessage`, `ClaudeParseResponse` and `Claude_header_generation`. All are included. The current `Token_Usage_Update`, `Conversation_Status_Saving`, `disp_status_table`, `Load_API_Keys_From_File` and `LLM_API_Keys_Setup` are supplied under `source/runtime/`; state saving includes Token_Usage and LLM_Watchdog.

## Original project helpers still required for full batch execution

| Helper/resource | Status |
| --- | --- |
| `CerBot_Decision_Three.m` | Called by the batch after routing. Only an older project copy was found; it has not been substituted for the provider-independent project version. |
| `Funzionalità_Simulatore_Raccolta.txt`, `Funzionalità_Simulatore_Elaborazione.txt` | Read by the unchanged Tartarone sections of agent definitions; not supplied. |
| `LLM_API_KEYS.txt` | Local runtime resource only; deliberately excluded from publication. |

The supplied batch passes `LLM_API_KEYS.txt` explicitly to `Load_API_Keys_From_File`. This loader requires both OPENAI_API_KEY and ANTHROPIC_API_KEY to be present and non-empty, even if the selected experiment uses one provider. Its no-argument default instead looks for api_keys.txt beside the helper. `LLM_API_Keys_Setup` then reads the environment into the provider-key structure. A placeholder-only example is included in `config/LLM_API_KEYS.example.txt`; keep the completed file local. Neither helper calls another custom function. No credential values are included.

The batch also retains Windows-specific paths and the baseline folder convention `Classification Test/baselines`. The repository organizes baseline sources in `source/baselines`. Using the full runner requires pointing that variable to the actual local folder and restoring the original project helper paths. No silent portability rewrite was applied to the experimental source.

Functions for live HMI/Telegram messaging and the complete EMS/simulator belong to branches outside `Classification_Test_ON = 1` and are not packaged as a complete application.

## Known mapper compatibility detail

The supplied mapper recognizes the historical labels `ADMIN_BROADCAST_ABORT` and `ADMIN_BROADCAST_OTHER`, returning `ABORT`/`OTHER`. The newer Single prompt instead declares `ADMIN_BROADCAST_MSG_ABORT` and `ADMIN_BROADCAST_MSG_OTHER`. These two outputs fall back to CLASSLESS in the supplied mapper. Neither is one of the 19 benchmark target labels. This mismatch is documented rather than silently corrected in the archived implementation.

## Analysis and Python dependencies

`Classification_Dataset_Setup` requires Excel columns `id`, `text`, `class`; row ordering must remain unchanged because rows 551 onward receive the role prefix `ADMIN:`. The main result elaboration and confusion evaluator include their own local helper functions and require the original raw run files. Read-only inspection of supplied CSV/MAT exports does not require API access.

Python baseline requirements are supplied with the original code. The saved model metadata records exact package versions. The semantic encoder must be downloaded separately at the pinned revision before MiniLM inference. The original trained head and TF-IDF pipeline are included; no training has been rerun.
