function LLM_API_Keys = LLM_API_Keys_Setup()
%LLM_API_KEYS_SETUP Load provider API keys from environment variables.
%
% Required only for the provider that is actually used:
%   OPENAI_API_KEY
%   ANTHROPIC_API_KEY
%
% Keys are deliberately not hard-coded into CERBot source files.

    LLM_API_Keys = struct( ...
        "OpenAI",    string(getenv("OPENAI_API_KEY")), ...
        "Anthropic", string(getenv("ANTHROPIC_API_KEY")) ...
    );
end
