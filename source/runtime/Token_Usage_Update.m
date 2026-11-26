function [Token_Usage, Call_Token_Usage] = Token_Usage_Update(Token_Usage, Call_Token_Usage, Call_Type)
%%% Call_Type può essere "Class" o "Answer"
%% Call_Type: "Class" oppure "Answer"

if Call_Token_Usage.Total <= 0
    return
end

Token_Fields = { ...
    'Input', ...
    'Input_Ordinary', ...
    'Input_Cached', ...
    'Input_Cache_Write', ...
    'Output', ...
    'Output_Reasoning', ...
    'Total'};

%% Ultimo messaggio + cumulativo
for k = 1:numel(Token_Fields)
    Field = Token_Fields{k};

    Token_Usage.Last.(Field) = Token_Usage.Last.(Field) +  Call_Token_Usage.(Field);
    Token_Usage.Cumulative.(Field) = Token_Usage.Cumulative.(Field) +  Call_Token_Usage.(Field);
end

%% Suddivisione per tipo di chiamata
switch Call_Type

    case "Class"
        for k = 1:numel(Token_Fields)
            Field = Token_Fields{k};
            Token_Usage.Classifier.(Field) = Token_Usage.Classifier.(Field) + Call_Token_Usage.(Field);
        end

    case "Answer"
        for k = 1:numel(Token_Fields)
            Field = Token_Fields{k};
            Token_Usage.Answer.(Field) = Token_Usage.Answer.(Field) + Call_Token_Usage.(Field);
        end

end








% if Call_Token_Usage.Total > 0
% 
%     % Ultimo messaggio
%     Token_Usage.Last.Input = ...
%         Token_Usage.Last.Input + Call_Token_Usage.Input;
% 
%     Token_Usage.Last.Output = ...
%         Token_Usage.Last.Output + Call_Token_Usage.Output;
% 
%     Token_Usage.Last.Total = ...
%         Token_Usage.Last.Total + Call_Token_Usage.Total;
% 
%     % Totale conversazione
%     Token_Usage.Cumulative.Input = ...
%         Token_Usage.Cumulative.Input + Call_Token_Usage.Input;
% 
%     Token_Usage.Cumulative.Output = ...
%         Token_Usage.Cumulative.Output + Call_Token_Usage.Output;
% 
%     Token_Usage.Cumulative.Total = ...
%         Token_Usage.Cumulative.Total + Call_Token_Usage.Total;
% 
%     switch Call_Type
%         case "Class"
%             % Questi token appartengono alla classificazione
%             Token_Usage.Cumulative.Classifier = Token_Usage.Cumulative.Classifier + Call_Token_Usage.Total;
% 
%         case "Answer"
%             % Questi token appartengono alle risposte
%             Token_Usage.Cumulative.Answer = Token_Usage.Cumulative.Answer + Call_Token_Usage.Total;
%     end
% end