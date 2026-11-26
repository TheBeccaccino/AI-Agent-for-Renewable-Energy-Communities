function response = ClaudePostMessage(userMessage, apiKey, agent_data, timeout_s)
%CLAUDEPOSTMESSAGE Send one stateless request to the Anthropic Messages API.
%
% The function accepts the CERBot agent_data structure already used by the
% OpenAI implementation and maps the relevant fields to Claude:
%
%   agent_data.model              -> model
%   agent_data.instructions       -> system prompt
%   agent_data.reasoning.effort   -> output_config.effort
%   agent_data.max_tokens         -> max_tokens (optional)
%
% OpenAI-specific fields such as background, prompt_cache_key and
% text.verbosity are intentionally ignored.
%
% For classification tests, the static system prompt is marked with an
% explicit ephemeral cache breakpoint. The variable user message remains
% outside that cached prefix.

    if nargin < 4 || isempty(timeout_s)
        timeout_s = 300;
    end

    url = 'https://api.anthropic.com/v1/messages';
    headers = Claude_header_generation(apiKey, timeout_s);

    data = struct();

    %% Model
    if isfield(agent_data, 'model') && ~isempty(agent_data.model)
        data.model = char(string(agent_data.model));
    else
        data.model = 'claude-haiku-5-5';
    end

    %% Maximum generated tokens
    % Thinking tokens are included in max_tokens on current Claude models.
    if isfield(agent_data, 'max_tokens') && ~isempty(agent_data.max_tokens)
        data.max_tokens = double(agent_data.max_tokens);
    else
        data.max_tokens = 4096;
    end

    %% System prompt + explicit prompt-cache breakpoint
    if isfield(agent_data, 'instructions') && ~isempty(agent_data.instructions)
        system_block = struct( ...
            'type', 'text', ...
            'text', char(string(agent_data.instructions)), ...
            'cache_control', struct('type', 'ephemeral'));

        % Cell wrapper forces JSON array encoding.
        data.system = {system_block};
    end

    %% User message
    user_block = struct( ...
        'role', 'user', ...
        'content', char(string(userMessage)));

    % Cell wrapper forces JSON array encoding.
    data.messages = {user_block};

    %% Effort
    if isfield(agent_data, 'reasoning') && ...
            isstruct(agent_data.reasoning) && ...
            isfield(agent_data.reasoning, 'effort') && ...
            ~isempty(agent_data.reasoning.effort)

        effort = lower(string(agent_data.reasoning.effort));

        % OpenAI's "minimal" has no direct Claude equivalent.
        if effort == "minimal"
            effort = "low";
        end

        allowed_effort = ["low", "medium", "high", "xhigh", "max"];
        if any(effort == allowed_effort)
            data.output_config = struct('effort', char(effort));
        end
    end

    %% Claude Haiku 5.5 uses adaptive thinking by default.
    % Set it explicitly so that the experimental configuration is recorded
    % in the request and reasoning-token accounting remains meaningful.
    data.thinking = struct('type', 'adaptive');

    %% API call
    response = webwrite(url, data, headers);
end
