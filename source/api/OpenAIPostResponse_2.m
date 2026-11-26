function responseId = OpenAIPostResponse_2(userMessage, apiKey, previous_id, agent_data)

% URL
url = ['https://api.openai.com/v1/responses'];

% Headers per la richiesta
headers = GPT_header_generation_new(apiKey);
    
%% Import della Struttura Data
data = agent_data;

% mantenimento del contesto
if ~strcmp(previous_id,"new_chat") && ~strcmp(previous_id,"")
    data.previous_response_id = previous_id;
end

%% API POST call
response = webwrite(url, data, headers);

% Prerarazione dell' OUTPUT
responseId = response.id;
