function [status_LLM, Answer_message, Answer_ID, Call_Token_Usage, LLM_Watchdog] = ...
    Claude_LLM_Interaction(status_LLM, Message, previous_ID, agent_data, ...
                           Answer_ID, apiKey, LLM_Watchdog)
%CLAUDE_LLM_INTERACTION Claude equivalent of OpenAI_LLM_Interaction.
%
% Designed as a near drop-in replacement for CERBot classification tests:
%
% [status_LLM, Answer_message, Answer_ID, Call_Token_Usage, LLM_Watchdog] = ...
%     Claude_LLM_Interaction(status_LLM, Message, previous_ID, ...
%                            agent_data, Answer_ID, apiKey, LLM_Watchdog)
%
% IMPORTANT DIFFERENCE
% --------------------
% The standard Anthropic Messages API returns a complete message
% synchronously; it does not expose the same per-request background/polling
% lifecycle used by the OpenAI Responses API in the current CERBot code.
%
% Consequently, for Claude:
%   State 0 -> State 1 -> API request -> State 3
%
% State 2 (pending/polling) is not used.
%
% This is appropriate for the stateless intent-classification experiments.
% `previous_ID` and `Answer_ID` are NOT used as conversation-memory handles.
% The returned Claude message ID is stored in Answer_ID only for logging.
%
% For a future conversational Claude backend, the complete message history
% should be stored and resent through the Messages API rather than relying on
% a previous-response ID.

    %% Initialize outputs
    Answer_message = "";

    Call_Token_Usage = struct( ...
        "Input",             0, ...
        "Input_Ordinary",    0, ...
        "Input_Cached",      0, ...
        "Input_Cache_Write", 0, ...
        "Output",            0, ...
        "Output_Reasoning",  0, ...
        "Total",             0);

    %#ok<NASGU>
    previous_ID = previous_ID; % kept only for interface compatibility

    %% State initialization
    if status_LLM == 0
        status_LLM = 1;
    end

    %% Synchronous Claude request
    if status_LLM == 1

        if ~isfield(LLM_Watchdog, 'Retry_Count') || ...
                isempty(LLM_Watchdog.Retry_Count)
            LLM_Watchdog.Retry_Count = 0;
        end

        if ~isfield(LLM_Watchdog, 'Max_Retry') || ...
                isempty(LLM_Watchdog.Max_Retry)
            LLM_Watchdog.Max_Retry = 2;
        end

        if ~isfield(LLM_Watchdog, 'Timeout') || ...
                isempty(LLM_Watchdog.Timeout)
            LLM_Watchdog.Timeout = 300;
        end

        LLM_Watchdog.Request_tstart = tic;

        try
            response = ClaudePostMessage( ...
                Message, apiKey, agent_data, LLM_Watchdog.Timeout);

            [Answer_message, Answer_ID, Call_Token_Usage] = ...
                ClaudeParseResponse(response);

            % The HTTP request completed successfully.
            status_LLM = 3;
            LLM_Watchdog.Request_tstart = [];

        catch ME
            if LLM_Watchdog.Retry_Count < LLM_Watchdog.Max_Retry
                LLM_Watchdog.Retry_Count = LLM_Watchdog.Retry_Count + 1;

                fprintf( ...
                    "Claude API error. Retry %d/%d. %s\n", ...
                    LLM_Watchdog.Retry_Count, ...
                    LLM_Watchdog.Max_Retry, ...
                    string(ME.message));

                % Keep State 1: the main CERBot loop will retry.
                status_LLM = 1;
                Answer_ID = "";
                Answer_message = "";
                LLM_Watchdog.Request_tstart = [];

            else
                status_LLM = 3;
                Answer_ID = "";
                Answer_message = "LLM_API_ERROR";
                LLM_Watchdog.Request_tstart = [];

                warning( ...
                    "Claude_LLM_Interaction:MaxRetry", ...
                    "Claude request failed after %d retries: %s", ...
                    LLM_Watchdog.Max_Retry, ME.message);
            end
        end
    end
end
