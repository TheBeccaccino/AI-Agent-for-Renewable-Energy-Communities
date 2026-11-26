# Experimental configuration documented by the source

The main LLM campaign was completed around mid-October 2026, as reported by the authors. This supplement was prepared on 26 November 2026 and also contains revision-stage local-baseline results. File preparation dates are not model inference dates.

## Data and roles

All four datasets are synthetic Italian intent corpora: ChatGPT for development and gate calibration; Claude, Grok and DeepSeek for external cross-generator testing. Each has 950 messages and 19 intents with 50 messages per intent. External pooling comprises 2,850 messages. `id`, `text`, `class` are the Excel columns. Unique chat IDs prevent conversation history from being shared between benchmark samples. This is not a field or human-labelled evaluation.

The loader leaves the first 550 messages as user messages and prefixes messages 551–950 with `ADMIN:`. Preserve ordering. The local preprocessor lowercases and trims, normalizes listed accented vowels, replaces other characters except letters, digits, colon and percent with spaces, and collapses whitespace. Inspect `normalizeMessage.m` for the exact expressions.

## Architectures

Single invokes the full-tree prompt. H-Single accepts any complete local route and otherwise invokes Single. HS-Single accepts only complete routes whose final label is in the fixed trusted set; every other original message is delegated to Single, with no partial local route retained.

Trusted classes: RESET, CHANGE, SIMULATION, INSULT, ADVICE_OFF, AUTO_PLANNING_ON, BESS_COORD_ON, ADVICE_COORD_ON. The batch documents selection by observed development precision at least 95% and at least 10 local predictions per class. The list is fixed during external testing; the batch does not recompute calibration statistics.

## Models and request configuration

| Alias | API identifier |
| --- | --- |
| nano | `gpt-5-nano` |
| luna | `gpt-6-luna` |
| sol | `gpt-6.1-sol` |
| haiku | `claude-haiku-5-5` |

These are the identifiers in the supplied resolver. No dated provider snapshot IDs were inferred. `class_effort` comes from the explicit batch configuration table. The six CERBot classifiers request low text verbosity and use separate static cache keys where specified. Classification calls use `new_chat`; role prefixes and any explicitly supplied broadcast routing context are part of the input.

The supplied OpenAI adapter uses Responses API background requests and polling. The supplied Claude adapter uses synchronous Messages API calls, `anthropic-version: 2023-06-01`, adaptive thinking and default max_tokens 4096 when not overridden; minimal effort is mapped to low. The batch initializes timeout 300 seconds and Max_Retry 2. The recovered OpenAI HTTP options separately set an HTTP timeout of 120 seconds. See adapters for their different failure handling. Temperature and API generation seeds are not explicitly set in these supplied request builders; no numerical defaults are invented here. The baseline training seed is 20261120.

## Accounting and interpretation

`Dataset_Latency` is elapsed workflow time per message, including scheduling/polling and the configured display overhead; it is not an isolated provider latency. Compare routing architectures within the same model. Python baseline timing in the original score files measures a different execution boundary and is identified separately.

Classifier token counts and answer tokens are separate. Cached input denotes cache reads. Non-cached input used in paper tables can include ordinary input plus cache writes; these categories need their respective rates when costing. Reasoning is contained in output and must not be counted twice. Last, Cumulative, Classifier and Answer token scopes overlap and must not be summed together.

Cost estimates concern classifier API tokens under the paper's pricing assumptions, not infrastructure, full conversation generation, EMS execution or a complete service bill. Recorded watchdog counters are final state rather than a complete historical retry ledger. A zero token count is not a direct security or open-set rejection measurement.

Baseline development OOF estimates belong to the five-fold stratified group protocol. Final fitted-model ChatGPT predictions in the batch exports are training-set evaluations. The final classifiers are evaluated on the external datasets without further fitting. Full synthetic external sets remain archived as supplied; their interpretation must account for any corpus overlap separately.
