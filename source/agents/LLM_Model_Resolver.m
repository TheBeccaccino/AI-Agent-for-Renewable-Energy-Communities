function [Provider, Full_Model_Name] = LLM_Model_Resolver(Model_Name)
%LLM_MODEL_RESOLVER Resolve CERBot model aliases and infer the LLM provider.
%
% Examples:
%   [p,m] = LLM_Model_Resolver("nano")
%       -> p = "OpenAI",    m = "gpt-5-nano"
%
%   [p,m] = LLM_Model_Resolver("haiku")
%       -> p = "Anthropic", m = "claude-haiku-5-5"
%
% The function also accepts the full API model IDs directly.
% Adding a new model/provider should normally require editing only this file.

    Model_Name = lower(strtrim(string(Model_Name)));

    switch Model_Name
        % ---------------- OpenAI aliases ----------------
        case {"nano", "gpt-5-nano"}
            Provider = "OpenAI";
            Full_Model_Name = "gpt-5-nano";

        case {"luna", "gpt-6-luna"}
            Provider = "OpenAI";
            Full_Model_Name = "gpt-6-luna";

        case {"sol", "gpt-6.1-sol"}
            Provider = "OpenAI";
            Full_Model_Name = "gpt-6.1-sol";

        % ---------------- Anthropic aliases -------------
        case {"haiku", "haiku-5.5", "claude-haiku-5-5"}
            Provider = "Anthropic";
            Full_Model_Name = "claude-haiku-5-5";

        otherwise
            % Future-proof fallback when a full model ID is supplied.
            if startsWith(Model_Name, "gpt-")
                Provider = "OpenAI";
                Full_Model_Name = Model_Name;

            elseif startsWith(Model_Name, "claude-")
                Provider = "Anthropic";
                Full_Model_Name = Model_Name;

            else
                error( ...
                    "LLM_Model_Resolver:UnknownModel", ...
                    "Unknown LLM model alias/ID: %s", ...
                    Model_Name);
            end
    end
end
