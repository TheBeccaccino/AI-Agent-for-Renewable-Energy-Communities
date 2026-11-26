function [Answer_message, Answer_ID, Call_Token_Usage] = ClaudeParseResponse(response)
%CLAUDEparserESPONSE Extract text, response id, and token accounting.
%
% Anthropic usage semantics differ from OpenAI when prompt caching is used:
%   usage.input_tokens                  = uncached ordinary input
%   usage.cache_read_input_tokens       = input served from cache
%   usage.cache_creation_input_tokens   = input written to cache
%
% Therefore:
%   Input = Ordinary + Cached + Cache_Write
%
% output_tokens already includes thinking tokens. Output_Reasoning is only
% a decomposition and MUST NOT be added again when computing total cost.

    Answer_message = "";
    Answer_ID = "";

    Call_Token_Usage = struct( ...
        "Input",             0, ...
        "Input_Ordinary",    0, ...
        "Input_Cached",      0, ...
        "Input_Cache_Write", 0, ...
        "Output",            0, ...
        "Output_Reasoning",  0, ...
        "Total",             0);

    %% Response ID
    if isfield(response, 'id') && ~isempty(response.id)
        Answer_ID = string(response.id);
    end

    %% Extract only visible text blocks
    if isfield(response, 'content') && ~isempty(response.content)
        content = response.content;
        text_parts = strings(0,1);

        if iscell(content)
            for k = 1:numel(content)
                block = content{k};
                if isstruct(block) && isfield(block, 'type') && ...
                        strcmp(string(block.type), "text") && ...
                        isfield(block, 'text')
                    text_parts(end+1,1) = string(block.text); %#ok<AGROW>
                end
            end
        elseif isstruct(content)
            for k = 1:numel(content)
                block = content(k);
                if isfield(block, 'type') && ...
                        strcmp(string(block.type), "text") && ...
                        isfield(block, 'text')
                    text_parts(end+1,1) = string(block.text); %#ok<AGROW>
                end
            end
        end

        if ~isempty(text_parts)
            Answer_message = strjoin(text_parts, newline);
        end
    end

    %% Token usage
    if isfield(response, 'usage') && ~isempty(response.usage)
        usage = response.usage;

        ordinary = getNumericField(usage, 'input_tokens');
        cached   = getNumericField(usage, 'cache_read_input_tokens');
        written  = getNumericField(usage, 'cache_creation_input_tokens');
        output   = getNumericField(usage, 'output_tokens');

        Call_Token_Usage.Input_Ordinary    = ordinary;
        Call_Token_Usage.Input_Cached      = cached;
        Call_Token_Usage.Input_Cache_Write = written;
        Call_Token_Usage.Input             = ordinary + cached + written;
        Call_Token_Usage.Output            = output;

        if isfield(usage, 'output_tokens_details') && ...
                ~isempty(usage.output_tokens_details)

            details = usage.output_tokens_details;
            Call_Token_Usage.Output_Reasoning = ...
                getNumericField(details, 'thinking_tokens');
        end

        Call_Token_Usage.Total = ...
            Call_Token_Usage.Input + Call_Token_Usage.Output;
    end
end


function value = getNumericField(s, field_name)
    value = 0;

    if isstruct(s) && isfield(s, field_name)
        candidate = s.(field_name);

        if ~isempty(candidate)
            candidate = double(candidate);

            if isscalar(candidate) && isfinite(candidate)
                value = candidate;
            end
        end
    end
end
