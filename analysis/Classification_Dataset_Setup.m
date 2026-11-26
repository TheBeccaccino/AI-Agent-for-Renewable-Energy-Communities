function [n_message, Message_list, Update_ID_list, chat_ID_list, Correct_Class_list] = Classification_Dataset_Setup(Dataset)
%% Dataset
%%% Scelte disponibili: "ChatGPT" % "Claude" % "Grok" % "DeepSeek" 
Dataset_name = strcat("Classification Dataset ", Dataset, ".xlsx");

%% Recupero del Dataset
Class_Dataset = readtable (Dataset_name);
msg_id = Class_Dataset.id;
msg_text = Class_Dataset.text;
msg_class = Class_Dataset.class;

n_message = size(msg_text,1);

%% Chat_ID_list
chat_ID_list = string(msg_id');

%% Message_list
Message_list = string(msg_text');
Message_list(551:end) = strcat("ADMIN: ", Message_list(551:end));

%% Update_ID_list
Update_ID_list = ones(1, n_message);

%% Correct_Class_list
Correct_Class_list = string(msg_class');

a=2;















