function response = OpenAIGetResponse(apiKey, answer_id)

% URL
url = ['https://api.openai.com/v1/responses/', char(answer_id)];

% Headers per la richiesta
headers = GPT_header_generation_new(apiKey);
    
% API POST call
response = webread(url, headers);




