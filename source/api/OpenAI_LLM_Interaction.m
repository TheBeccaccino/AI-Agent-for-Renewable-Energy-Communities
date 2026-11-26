function [status_LLM, Answer_message, Answer_ID, Call_Token_Usage, LLM_Watchdog] = OpenAI_LLM_Interaction(status_LLM, Message, previous_ID, agent_data, Answer_ID, apiKey, LLM_Watchdog)
%% Inizializzazione variabili
Answer_message = "";
Call_Token_Usage = struct( ...
    "Input",             0, ...
    "Input_Ordinary",    0, ...
    "Input_Cached",      0, ...
    "Input_Cache_Write", 0, ...
    "Output",            0, ...
    "Output_Reasoning",  0, ...
    "Total",             0);

%% Gestione dello Stato
if status_LLM == 0
    status_LLM = 1;
end

if status_LLM == 1
    %%% estrazione dati chat
    agent_data.input = Message;
    Answer_ID = OpenAIPostResponse_2(Message, apiKey, previous_ID, agent_data);
    Answer_ID = string(Answer_ID);
    LLM_Watchdog.Request_tstart = tic;

    status_LLM = 2;
    Answer_message = "";
end

if status_LLM == 2
    %%% estrazione dati chat
    response = OpenAIGetResponse(apiKey, Answer_ID);
    response_status = string(response.status);

    %%% Interazione con LLM completata con successo
    if strcmp(response_status,"completed")
        %%% Answer 
        %%% Answer extraction compatible with different response formats
        if iscell(response.output)
            % Output returned as cell array
            output_item = response.output{end};
        
        else
            % Output returned as struct
            output_item = response.output(end);
        
        end
        
        
        if iscell(output_item.content)
            % Content returned as cell array
            content_item = output_item.content{end};
        
        else
            % Content returned as struct
            content_item = output_item.content(end);
        
        end
    
    
        Answer_message = string(content_item.text);
        
        %%% Token Count
        Call_Token_Usage.Input  = double(response.usage.input_tokens);
        Call_Token_Usage.Output = double(response.usage.output_tokens);
        Call_Token_Usage.Total  = double(response.usage.total_tokens);
        status_LLM = 3;

        
        %%% Input token details
        if isfield(response.usage, "input_tokens_details") && ...
                ~isempty(response.usage.input_tokens_details)
        
            Input_Details = response.usage.input_tokens_details;
        
            if isfield(Input_Details, "cached_tokens") && ...
                    ~isempty(Input_Details.cached_tokens)
        
                Call_Token_Usage.Input_Cached = ...
                    double(Input_Details.cached_tokens);
            end
        
            if isfield(Input_Details, "cache_write_tokens") && ...
                    ~isempty(Input_Details.cache_write_tokens)
        
                Call_Token_Usage.Input_Cache_Write = ...
                    double(Input_Details.cache_write_tokens);
            end
        end
        
        %%% Ordinary input
        Call_Token_Usage.Input_Ordinary = ...
            Call_Token_Usage.Input ...
            - Call_Token_Usage.Input_Cached ...
            - Call_Token_Usage.Input_Cache_Write;
        
        %%% Output token details
        if isfield(response.usage, "output_tokens_details") && ...
                ~isempty(response.usage.output_tokens_details)
        
            Output_Details = response.usage.output_tokens_details;
        
            if isfield(Output_Details, "reasoning_tokens") && ...
                    ~isempty(Output_Details.reasoning_tokens)
        
                Call_Token_Usage.Output_Reasoning = ...
                    double(Output_Details.reasoning_tokens);
            end
        end
        
    %%% Interazione con LLM incompleta
    elseif strcmp(response_status,"incomplete")
        status_LLM = 3;
        Answer_message = "issue with the message";
        disp("issue with the message")
    
    %%% Timeout scaduto    
    elseif toc(LLM_Watchdog.Request_tstart) > ...
            LLM_Watchdog.Timeout

        if LLM_Watchdog.Retry_Count < LLM_Watchdog.Max_Retry
            LLM_Watchdog.Retry_Count = LLM_Watchdog.Retry_Count + 1;
            fprintf( "LLM timeout. Retry %d/%d\n", LLM_Watchdog.Retry_Count, LLM_Watchdog.Max_Retry);
            status_LLM = 1;
            Answer_ID = "";
            LLM_Watchdog.Request_tstart = [];

        else
            status_LLM = 3;
            Answer_message = "LLM_TIMEOUT";

        end
    end
end
