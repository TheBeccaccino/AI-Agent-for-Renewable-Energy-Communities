clear all

%% ================================================================
%  CERBOT CLASSIFICATION BATCH TEST - TEST ONLY
%  This file is intentionally restricted to Classification_Test_ON = 1.
%  It executes multiple classifier configurations sequentially.
%  Two MATLAB instances can be run in parallel by assigning disjoint
%  Config_Start_Index / Config_End_Index ranges.
% ================================================================

%% Estensione percorsi
addpath Chatbot_functions\API_GPT_functions\
addpath Chatbot_functions\
addpath CerBot\
addpath CerBot\local_classifiers\
addpath CerBot\output_validators\
addpath Chatbot_functions\functionalities\
addpath 'Classification Test'\
addpath 'G:\.shortcut-targets-by-id\1nK67-5BmEwHmy7Z2_J2UQr8mzxR-OqDw\Prototipo simulatore 1\Prove per chatbot'
addpath 'G:\.shortcut-targets-by-id\1nK67-5BmEwHmy7Z2_J2UQr8mzxR-OqDw\Prototipo simulatore 1\Prove per chatbot\dati_arera\2022'

%% Technology used
Agent_used = "CerBot";
HMI_choice = "Lovable";
LLM_choice = "Automatic"; % provider inferred from model
Classification_Test_ON = 1; %#ok<NASGU> % TEST-ONLY: do not set to 0

%% API credentials
% Provider keys are loaded once. Only the key corresponding to the model
% selected in Test_Configurations is required by LLM_Interaction.
% Environment variables:
%   OPENAI_API_KEY
%   ANTHROPIC_API_KEY
%% API credentials
Load_API_Keys_From_File('LLM_API_KEYS.txt');
LLM_API_Keys = LLM_API_Keys_Setup();

% Telegram is not used in Classification Test mode.
Telegram_token = "";

%% ================================================================
%  BATCH CONFIGURATIONS
%  Columns: [model, reasoning effort, classifier architecture]
% ================================================================
Test_Configurations = [ ...
    "sol",  "low",  "Single";   ... % 1 - Single Sol Low
    "luna", "low",  "Single";   ... % 2 - Single Luna Low
    "sol",  "high", "Single";   ... % 3 - Single Sol High
    "nano", "low",  "Hybrid";   ... % 4 - Hybrid Nano Low
    "nano", "high", "Hybrid";   ... % 5 - Hybrid Nano High
    "luna", "low",  "Hybrid";   ... % 6 - Hybrid Luna Low
    "luna", "high", "Hybrid";   ... % 7 - Hybrid Luna High
    "sol",  "low",  "Hybrid";   ... % 8 - Hybrid Sol Low
    "sol",  "high", "Hybrid";   ... % 9 - Hybrid Sol High
    "luna", "low",  "H-Single"; ... % 10 - Local full-tree gate + Single Luna Low
    "luna", "low",  "HS-Single"; ... % 11 - Selective local gate + Single Luna Low
    "luna",  "low", "Single";    ... % 12 - Single Luna Low
    "nano",  "low", "H-Single";  ... % 13 - Local full-tree gate + Single Nano Low
    "nano",  "low", "HS-Single"; ... % 14 - Selective local gate + Single Nano Low
    "haiku", "low", "Single";    ... % 15 - Single Claude Haiku 5.5 Low
    "haiku", "low", "H-Single";  ... % 16 - Local full-tree gate + Claude Haiku 5.5 Low
    "haiku", "low", "HS-Single"; ... % 17 - Selective local gate + Claude Haiku 5.5 Low
    "nano", "low", "TF-IDF";    ... % 18 - TF-IDF + regressione logistica locale
    "nano", "low", "MiniLM"     ... % 19 - MiniLM + regressione logistica locale
    ];

N_Configurations = size(Test_Configurations,1);

%% Manual range - useful for two parallel MATLAB runs
% Examples:
%   Run only the new selective H-Single test:
%       Config_Start_Index = 11; Config_End_Index = 11;
%   Split the complete grid over two MATLAB instances:
%       MATLAB instance A -> Config_Start_Index = 1; Config_End_Index = 5;
%       MATLAB instance B -> Config_Start_Index = 6; Config_End_Index = 11;
Config_Start_Index = 18;
Config_End_Index   = 19;

if Config_Start_Index < 1 || Config_End_Index > N_Configurations || ...
        Config_Start_Index > Config_End_Index
    error('Invalid configuration range.');
end

%% Modelli locali addestrati
if Config_End_Index >= 18
    Local_Baselines_Folder = fullfile(pwd, 'Classification Test', 'baselines');
    Local_Python_Executable = fullfile(getenv('LOCALAPPDATA'), ...
        'CERBot', 'python-env', 'Scripts', 'python.exe');
    Local_Python_Environment = pyenv;
    if ~strcmpi(Local_Python_Environment.Executable, Local_Python_Executable) || ...
            string(Local_Python_Environment.ExecutionMode) ~= "OutOfProcess"
        pyenv('Version', Local_Python_Executable, ...
            'ExecutionMode', 'OutOfProcess');
    end
    insert(py.sys.path, int32(0), char(Local_Baselines_Folder));
    Local_Baselines_Module = py.importlib.import_module('baselines');
end

%% Run management
% true  -> delete an existing unfinished/current copy of the SAME config and
%          start again from message 1.
% false -> resume from the saved D value when files already exist.
Force_Fresh_Run = true;

% Optional suffix for independent replications, e.g. "R2".
% Leave empty to obtain names such as Single_sol_low_Dataset_Result_Test.mat.
Run_Tag = "";

% Keep TRUE to preserve the timing conditions used in previous experiments.
% Set FALSE only if you intentionally want to exclude console-display overhead.
Show_Status_Table = true;

%% HS-Single selective local gate
% Only COMPLETE local routes ending in one of these classes are accepted.
% Every other locally resolved route is deliberately delegated to the
% Single-Stage LLM.
%
% Selection rule used here:
%   - observed local precision >= 95% on the validation dataset; AND
%   - at least 10 local predictions for that class.
%
% This keeps the gate conservative and avoids selecting classes whose apparent
% 100% precision was estimated from only a handful of local decisions.
% START and MSG_NOT_READY are therefore intentionally excluded despite 100%
% observed precision in the current validation set.
HS_Single_Trusted_Classes = [ ...
    "RESET", ...
    "CHANGE", ...
    "SIMULATION", ...
    "INSULT", ...
    "ADVICE_OFF", ...
    "AUTO_PLANNING_ON", ...
    "BESS_COORD_ON", ...
    "ADVICE_COORD_ON" ...
    ];

%% Dataset - loaded once and reused identically for every configuration
%%% Scelte disponibili: "ChatGPT" % "Claude" % "Grok" % "DeepSeek" 
Dataset = "ChatGPT";
[datasetsize, Dataset_Message_list, Dataset_Update_ID_list, Dataset_chat_ID_list, Correct_Class_list] = Classification_Dataset_Setup(Dataset); %#ok<ASGLU>

%% Token Usage template
Token_Detail_Template = struct( ...
    "Input",             0, ...
    "Input_Ordinary",    0, ...
    "Input_Cached",      0, ...
    "Input_Cache_Write", 0, ...
    "Output",            0, ...
    "Output_Reasoning",  0, ...
    "Total",             0);

Token_Usage_Template = struct( ...
    "Last",       Token_Detail_Template, ...
    "Cumulative", Token_Detail_Template, ...
    "Classifier", Token_Detail_Template, ...
    "Answer",     Token_Detail_Template ...
    );

%% LLM Watchdog Template
LLM_Watchdog_Template = struct( ...
    "Request_tstart", [], ...
    "Retry_Count",    0, ...
    "Timeout",        300, ...
    "Max_Retry",      2 ...
    );

%% Class List Template
Class_list_Template = struct( ...
    "MAIN", "", ...
    "EMS", "", ...
    "ADMIN", "", ...
    "ADMIN_EMS", "", ...
    "ADMIN_BRD", "" ...
    );

%% ================================================================
%  CONFIGURATION LOOP
% ================================================================
for Config_Index = Config_Start_Index:Config_End_Index

    % Ensure that structures from the previous configuration do not leak.
    clear CerBot Tartarone LLM_full_name LLM_provider model_local_tree model_single_tree

    LLM_model_used = char(Test_Configurations(Config_Index,1));
    class_effort   = char(Test_Configurations(Config_Index,2));
    Classificator  = Test_Configurations(Config_Index,3);

    % One source of truth: the model column selects both API model and provider.
    [LLM_provider, LLM_full_name] = LLM_Model_Resolver(LLM_model_used);

    fprintf('\n============================================================\n');
    fprintf('Configuration %d/%d: %s | %s | %s | provider=%s\n', ...
        Config_Index, N_Configurations, ...
        Classificator, string(LLM_model_used), string(class_effort), LLM_provider);
    fprintf('API model: %s\n', LLM_full_name);
    fprintf('============================================================\n');

    %% Agent definition
    % Execute the current LLM_agents_definition.m exactly as written, but
    % suppress its final shared "save LLM_agents" command. This avoids a
    % write race when two MATLAB instances run this batch file in parallel.
    Agent_Definition_Code = fileread('LLM_agents_definition.m');
    Agent_Definition_Code = regexprep( ...
        Agent_Definition_Code, ...
        '(?m)^\s*save\s+LLM_agents[^\r\n]*', ...
        '% save LLM_agents disabled by batch-test runner');
    eval(Agent_Definition_Code);

    %% Classifier architecture flags
    Selective_Local_Gate_ON = false;
    TF_IDF_Local_Gate_ON    = false;
    MiniLM_Local_Gate_ON    = false;

    if Classificator == "H-Single"
        % Full local-tree gate. If and only if the local tree cannot reach a
        % complete leaf, the complete message is delegated to Single-Stage.
        Single_Stage_LLM_ON     = true;
        Local_Classifier_ON     = true;
        LLM_based_Classifier_ON = false;

    elseif Classificator == "HS-Single"
        % Selective local-tree gate. The full local route is first computed,
        % but it is accepted only when its FINAL class belongs to the trusted
        % whitelist defined above. Otherwise the original message is sent to
        % the Single-Stage LLM.
        Single_Stage_LLM_ON     = true;
        Local_Classifier_ON     = true;
        LLM_based_Classifier_ON = false;
        Selective_Local_Gate_ON = true;

    elseif Classificator == "TF-IDF"
        Single_Stage_LLM_ON     = true; % Instradamento della classificazione completa
        Local_Classifier_ON     = true;
        LLM_based_Classifier_ON = false;
        TF_IDF_Local_Gate_ON    = true;
        Local_Model = Local_Baselines_Module.Router(char( ...
            fullfile(Local_Baselines_Folder, 'traditional_results', 'model')));

    elseif Classificator == "MiniLM"
        Single_Stage_LLM_ON     = true; % Instradamento della classificazione completa
        Local_Classifier_ON     = true;
        LLM_based_Classifier_ON = false;
        MiniLM_Local_Gate_ON    = true;
        Local_Model = Local_Baselines_Module.Router(char( ...
            fullfile(Local_Baselines_Folder, 'local_semantic', 'model')));
    else
        [Single_Stage_LLM_ON, Local_Classifier_ON, ...
            LLM_based_Classifier_ON] = Classificator_Set_Up(Classificator);
    end

    %% Output/state names
    % Hyphens are removed from the file label (H-Single -> HSingle, HS-Single -> HSSingle).
    Classificator_File_Label = replace(Classificator, "-", "");
    Classificator_label = Classificator_File_Label + "_" + string(LLM_model_used) + "_" + string(class_effort);

    if strlength(Run_Tag) > 0
        Classificator_label = Classificator_label + "_" + Run_Tag;
    end

    if ~strcmp(Dataset,"ChatGPT")
        Classificator_label = Classificator_label + "_" + Dataset;
    end


    Conversation_Status_name  = Classificator_label + "_conversation_status_CerBot_test";
    EMS_Agent_Info_name       = Classificator_label + "_EMS_Agent_Info_exchange_test";
    EMS_Agent_Admin_Info_name = Classificator_label + "_EMS_Agent_Admin_Info_exchange_test";
    Dataset_Results_name      = Classificator_label + "_Dataset_Result_Test";

    D = 1;

    %% Fresh run / resume management
    Config_Files = [ ...
        Conversation_Status_name + ".mat", ...
        EMS_Agent_Info_name + ".mat", ...
        EMS_Agent_Admin_Info_name + ".mat", ...
        Dataset_Results_name + ".mat" ...
        ];

    if Force_Fresh_Run
        for File_Index = 1:numel(Config_Files)
            if isfile(Config_Files(File_Index))
                delete(Config_Files(File_Index));
            end
        end
    end

%% Caricamento stato delle conversazioni
try
    load(Conversation_Status_name)
catch
    n_chat_open = 0;
    open_chat_list = string([]);
    previous_ID_list = string([]);
    last_update_list = [];
    Status_Chat = [];
    Status_LLM = [];
    Status_Sim = [];
    Message_actual = string([]);
    Answer_ID_list = string([]);
    Class_list = repmat(Class_list_Template, 1, 0);
    Class_ID_list = string([]);
    Sim_subclass_ID_list = string([]);
    EMS_subclass_ID_list = string([]);
    Admin_chat_ID = "";
    Admin_subclass_ID_old = "";
    Admin_EMS_subclass_ID_old = "";
    Admin_Broadcast_subclass_ID_old = "";
    Admin_Broadcast_Status = 0;
    Answer_list = string([]);
    Latency = [];
    msg_tstart = {};
    Token_Usage = repmat(Token_Usage_Template, 1, 0);
    LLM_Watchdog = repmat(LLM_Watchdog_Template, 1, 0);
    Conversation_Status_Saving
end

try 
    load(EMS_Agent_Info_name)
catch
    Status_EMS = struct(... 
    "Chat_CMD",          0, ...
    "Advice_ON",         0, ...
    "Advice_OFF",        0, ...
    "Load_Planning",     0, ...
    "Auto_Planning_On",  0, ...
    "Auto_Planning_Off", 0, ...
    "Message_Req",       0, ...
    "Message_from_EMS",  0 ...
    );
    save(EMS_Agent_Info_name, "Status_EMS") 
end

try
    load(EMS_Agent_Admin_Info_name)
catch
    Status_Admin_EMS = struct(... 
    "Chat_CMD",       0, ...
    "Advice_ON",      0, ...
    "Advice_OFF",     0, ...
    "BESS_Coord_On",  0, ...
    "BESS_Coord_Off", 0, ...
    "Load_Coord_On",  0, ...
    "Load_Coord_Off", 0, ...
    "Message_Req",    0, ...
    "Message_from_EMS", 0 ...
    );
    save(EMS_Agent_Admin_Info_name, "Status_Admin_EMS")  
end

try
    load(Dataset_Results_name)
catch
    Dataset_Latency = 0;
    Dataset_Token_Usage = repmat(Token_Usage_Template, 1, 0);
    save(Dataset_Results_name, "Dataset_Latency", "Dataset_Token_Usage", "D", "datasetsize")
end

if D > datasetsize
    fprintf('Configuration already complete: %s. Skipping.\n', Classificator_label);
    continue
end

% %% Simulation status
% try
%     load Simulation_request.mat
% catch
%     Sim_Req = [];
%     Input_struct_Sim = string([]);
%     Chat_ID_queque = [];
%     save Simulation_request.mat Sim_Req Input_struct_Sim Chat_ID_queque
% end
% 
% try
%     load Simulation_answer.mat
% catch
%     Sim_complete = [];
%     Sim_Result = string([]);
%     save Simulation_answer.mat Sim_complete Sim_Result
% end
% 
% % Aggiornamento CER Simulation Status
% try
%     load CER_Simulation_Status.mat
% catch
%     Simulation_Run_status = 0;
%     Input_struct_used = "";
%     Output_struct = "";
%     save CER_Simulation_Status.mat Simulation_Run_status Input_struct_used Output_struct
% end

%% lancio del ciclo
% url = 'https://api.telegram.org/bot<token>/METHOD_NAME';
LAST_UPDATE_ID = 0;
cycle_on = 1;
while cycle_on
    try
        %%% Gestione Chat       
        if ~Classification_Test_ON
            success = false;
            while ~success
                try
                        % La tua operazione qui
                        %result = operazione_che_può_fallire();
                %%% Valutazione dell' offset dell'ultimo messaggio ricevuto dal bot
                %%% ed elaborato
                offset = string(max(last_update_list));
                if size(offset,1) == 0
                    offset = 0;
                end
                success = true;  % Se arriva qui, è andata bene
                        
                catch e
                    fprintf('Errore: %s\n', e.message);
                    fprintf('Riprovo...\n');
                    pause(1);  % Aspetta 1 secondo prima di riprovare (opzionale)
                end
            end
            
            %%% mostra lo stato attuale della chat
            disp_CERbot_status_table

            %%% Scaricamento nuovi messaggi
            [n_message, Message_list, Update_ID_list, chat_ID_list] = New_Msg_Retrival(HMI_choice, Telegram_token, offset);

        else
                offset = string(max(last_update_list));
                if size(offset,1) == 0
                    offset = 0;
                end
                
                %%% Scaricamento nuovi messaggi
                % [n_message, Message_list, Update_ID_list, chat_ID_list] = New_Msg_Retrival(HMI_choice, Telegram_token, offset);
                n_message = 1;
                Message_list   = Dataset_Message_list(D);
                Update_ID_list = Dataset_Update_ID_list(D);
                chat_ID_list   = Dataset_chat_ID_list(D);
        end

        if n_message > 0
            %% Load degli stati
            load(Conversation_Status_name)
            load(EMS_Agent_Info_name)
            load(EMS_Agent_Admin_Info_name)
            % load Simulation_request.mat
            % load Simulation_answer.mat
            % load CER_Simulation_Status.mat
    
            %%% Verifica dei chat ID
            chat_ID_online = unique(chat_ID_list);
            n_chat_online = max(size(chat_ID_online,2));
            n_chat_open = max(size(open_chat_list));
        
            for c=1:n_chat_online
                chat_ID = chat_ID_online(c);
                
                %%% Controlliamo se la chat è già stata aperta in partenza. Se non è così associamo al chat_ID di telegram il set di variabili di stato necessarie
                %%% Estendiamo inoltre tutti gli stati delle chat
                chat_ID_check = find(open_chat_list == chat_ID_online(c));
                if isempty(chat_ID_check) %% chat aperta per la prima volta
                    open_chat_list = [open_chat_list, chat_ID];
                    n_chat_open = size(open_chat_list,2);
    
                    previous_ID_list = [previous_ID_list, "new_chat"];
                    Answer_ID_list = [Answer_ID_list, ""];
                    Class_ID_list = [Class_ID_list, ""];
                    Sim_subclass_ID_list = [Sim_subclass_ID_list, ""];
                    EMS_subclass_ID_list = [EMS_subclass_ID_list, ""];
                    Class_list(n_chat_open) = Class_list_Template;
                    last_update_list = [last_update_list, 0];
                    Status_Chat = [Status_Chat, 0];
                    Status_LLM = [Status_LLM, 0];
                    Status_Sim = [Status_Sim, 0];
                    Answer_list = [Answer_list, ""];
                    Message_actual = [Message_actual, ""];
                    Latency = [Latency, 0];
                    msg_tstart{n_chat_open} = [];
                    Token_Usage(n_chat_open) = Token_Usage_Template;
                    LLM_Watchdog(n_chat_open) = LLM_Watchdog_Template;

                    Status_EMS(n_chat_open) = struct(... 
                        "Chat_CMD",          0, ...
                        "Advice_ON",         0, ...
                        "Advice_OFF",        0, ...
                        "Load_Planning",     0, ...
                        "Auto_Planning_On",  0, ...
                        "Auto_Planning_Off", 0, ...
                        "Message_Req",       0, ...
                        "Message_from_EMS",  0 ...
                    );
                    % n_chat_open = n_chat_open + 1; 
                    Conversation_Status_Saving
                    save(EMS_Agent_Info_name, "Status_EMS")
                end
            end
    
            Update_ID_actual = last_update_list;
            for c=1:n_chat_online
                chat_ID = chat_ID_online(c);
                chat_ID_check = find(open_chat_list == chat_ID_online(c));
    
                %%% vediamo quali sono i messaggi associati alla chat
                chat_message_check = chat_ID_list == chat_ID;
                Update_ID_chat = Update_ID_list.*chat_message_check;
                Update_ID_check = find(Update_ID_chat > last_update_list(chat_ID_check),1);
    
                if ~isempty(Update_ID_check)
                    % Update_ID_list2 = Update_ID_chat.*Update_ID_check;
                    actual_message_ID = Update_ID_check;
                    Update_ID_actual(chat_ID_check) = Update_ID_chat(Update_ID_check);
                    % [Update_ID_actual(chat_ID_check),actual_message_ID] = min(Update_ID_chat.*Update_ID_check);
                    actual_message = Message_list(actual_message_ID);
                    if strcmp(actual_message,"/start")
                        actual_message = "Ciao! con chi parlo?";
                    end
                    
                    Message_Input(chat_ID_check) = actual_message;
    
                    if Status_Chat(chat_ID_check) == 0
                        Status_Chat(chat_ID_check) = 1;
                        msg_tstart{chat_ID_check} = tic;
                            
                        % Reset token usage relativo al nuovo messaggio
                        Token_Usage(chat_ID_check).Last = Token_Detail_Template;

                        % check timer LLM calls
                        LLM_Watchdog(chat_ID_check).Retry_Count = 0;
                    end
                else
                    Status_Chat(chat_ID_check) = 0;
                end
            end
        
            %% salvataggio dello stato delle conversazioni
            Conversation_Status_Saving
    
            %% Generazione delle risposte
            chat_online_indexes = find(Status_Chat,n_chat_open);
            for c = chat_online_indexes
    
            %%% Simulation Activity check    
            if Status_Sim(c) ~= 0 && Status_Chat(c) == 1 % Simulation still active
                Status_Chat(c) = 2;
            end
    
            if Show_Status_Table
                disp_status_table
            end
            
            %%%% CHATBOT THINKING THREE  
            switch Status_Chat(c)
                %%% CLASSIFICATION LAYER    
                case 1
                    Message_used = Message_Input(c);

                    Message_actual(c) = [ ...
                        "<MESSAGE>" + newline + ...
                        Message_used + newline + ...
                        "</MESSAGE>" ...
                        ];
                    previous_ID = char(previous_ID_list(c));
                    Class_ID = char(Class_ID_list(c));

                    if Single_Stage_LLM_ON
                        % =================================================
                        % SINGLE-STAGE / HYBRID-SINGLE CLASSIFICATION
                        %
                        % Single:
                        %   Local_Classifier_ON = false -> one Single-Stage LLM call.
                        %
                        % H-Single:
                        %   Local_Classifier_ON = true -> the COMPLETE local tree is
                        %   attempted first. Any complete local route is accepted.
                        %
                        % HS-Single:
                        %   the COMPLETE local tree is also attempted first, but a
                        %   local route is accepted only if its FINAL class is in
                        %   HS_Single_Trusted_Classes. All other messages are
                        %   delegated to the Single-Stage LLM.
                        % =================================================
                        Classification_Completed = false;
                        Local_FullTree_Resolved = false;

                        if Local_Classifier_ON && Status_LLM(c) == 0

                            if TF_IDF_Local_Gate_ON || MiniLM_Local_Gate_ON
                                Local_Result = Local_Model.classify(char(Message_used));
                                Local_Label = string(Local_Result{1});
                                Local_Class_list = Class_list_Template;

                                switch Local_Label
                                    case {"ADVICE_ON", "ADVICE_OFF", "LOAD_PLANNING", ...
                                            "AUTO_PLANNING_ON", "AUTO_PLANNING_OFF"}
                                        Local_Class_list.MAIN = "EMS";
                                        Local_Class_list.EMS = Local_Label;

                                    case {"BESS_COORD_ON", "BESS_COORD_OFF", ...
                                            "LOAD_COORD_ON", "LOAD_COORD_OFF", ...
                                            "ADVICE_COORD_ON", "ADVICE_COORD_OFF"}
                                        Local_Class_list.MAIN = "ADMIN";
                                        Local_Class_list.ADMIN = "EMS";
                                        Local_Class_list.ADMIN_EMS = Local_Label;

                                    case {"MSG_READY", "MSG_NOT_READY"}
                                        Local_Class_list.MAIN = "ADMIN";
                                        Local_Class_list.ADMIN = "BROADCAST";
                                        Local_Class_list.ADMIN_BRD = Local_Label;

                                    otherwise
                                        Local_Class_list.MAIN = Local_Label;
                                end
                                Local_FullTree_Resolved = true;

                            elseif Selective_Local_Gate_ON
                                [Local_FullTree_Resolved, Local_Class_list] = ...
                                    Try_Local_Selective_Tree( ...
                                        Message_used, ...
                                        Class_list_Template, ...
                                        Admin_Broadcast_Status, ...
                                        open_chat_list(c), ...
                                        Admin_chat_ID, ...
                                        HS_Single_Trusted_Classes);
                            else
                                [Local_FullTree_Resolved, Local_Class_list] = ...
                                    Try_Local_Full_Tree( ...
                                        Message_used, ...
                                        Class_list_Template, ...
                                        Admin_Broadcast_Status, ...
                                        open_chat_list(c), ...
                                        Admin_chat_ID);
                            end

                            if Local_FullTree_Resolved
                                Class_list(c) = Local_Class_list;
                                Classification_Completed = true;
                            end
                        end

                        if ~Local_FullTree_Resolved
                            Classifier_Message = [ ...
                                "<MESSAGE>" + newline + ...
                                Message_used + newline + ...
                                "</MESSAGE>" ...
                                ];

                            % Preserve the existing multi-turn broadcast logic.
                            if Admin_Broadcast_Status == 1 && ...
                                    string(open_chat_list(c)) == string(Admin_chat_ID)

                                Classifier_Message = [ ...
                                    "<ROUTING_CONTEXT>ADMIN_BROADCAST_ACTIVE</ROUTING_CONTEXT>" + newline + ...
                                    Classifier_Message ...
                                    ];
                            end

                            [Status_LLM(c), Route_message, Class_ID, Call_Token_Usage, LLM_Watchdog(c)] = ...
                                LLM_Interaction( ...
                                    Status_LLM(c), ...
                                    Classifier_Message, ...
                                    "new_chat", ...
                                    CerBot.SingleStage.Classificator, ...
                                    Class_ID, ...
                                    LLM_API_Keys, ...
                                    LLM_Watchdog(c));

                            [Token_Usage(c), Call_Token_Usage] = ...
                                Token_Usage_Update(Token_Usage(c), Call_Token_Usage, "Class");

                            Class_ID_list(c) = Class_ID;

                            if Status_LLM(c) == 3
                                [Class_list(c), Valid_Route] = ...
                                    CerBot_Map_SingleStage_Route( ...
                                        Route_message, ...
                                        Class_list_Template);

                                if ~Valid_Route
                                    disp("WARNING: invalid Single-Stage route. CLASSLESS fallback applied.")
                                end

                                Status_LLM(c) = 0;
                                Classification_Completed = true;
                            end
                        end

                        if Classification_Completed
                            % Continue through the SAME operational states used by
                            % the hierarchical implementation. For H-Single the
                            % complete local route is already stored in Class_list.
                            switch Class_list(c).MAIN
                                case "RESET"
                                    previous_ID_list(c) = "new_chat";
                                    Status_Chat(c) = 3;

                                case "SIMULATION"
                                    Status_Sim(c) = 1;
                                    Status_Chat(c) = 3;

                                case "EMS"
                                    Status_Chat(c) = 5;

                                case "ADMIN"
                                    Status_Chat(c) = 6;

                                otherwise
                                    Status_Chat(c) = 3;
                            end
                        end

                    else
                        % =================================================
                        % ORIGINAL HIERARCHICAL CLASSIFICATION
                        % Kept unchanged to preserve backward compatibility.
                        % =================================================
                        label = "UNRESOLVED";

                        % Class. Locale
                        if Local_Classifier_ON && Status_LLM(c) == 0
                            label = local_first_layer_Classify(Message_used);
                        end

                        % Class. LLM
                        if label == "UNRESOLVED" && LLM_based_Classifier_ON
                            [Status_LLM(c), Class_message, Class_ID,  Call_Token_Usage, LLM_Watchdog(c)] = LLM_Interaction( Status_LLM(c), Message_used, "new_chat", CerBot.Classificator, Class_ID, LLM_API_Keys, LLM_Watchdog(c));
                            [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update( Token_Usage(c), Call_Token_Usage, "Class");
                            Class_ID_list(c) = Class_ID;

                        elseif label == "UNRESOLVED"
                            Class_message = "CLASSLESS";
                            Status_LLM(c) = 3;

                        else
                            Class_message = label;
                            Status_LLM(c) = 3;
                        end

                        if Status_LLM(c) == 3
                            Class_list(c).MAIN = string(Class_message);
                            Status_LLM(c) = 0;

                            switch Class_list(c).MAIN
                                case "RESET"
                                    previous_ID_list(c) = "new_chat";
                                    Status_Chat(c) = 3;

                                case "SIMULATION"
                                    Status_Sim(c) = 1;
                                    Status_Chat(c) = 3;

                                case "EMS"
                                    Status_Chat(c) = 5;

                                case "ADMIN"
                                    Status_Chat(c) = 6;

                                otherwise
                                    Status_Chat(c) = 3;
                            end
                        end
                    end

                %%% SIMULATION SUBCLASSIFICATION LAYER
                case 2
                    Message_used = Message_actual(c);
                    Sim_subclass_ID = char(Sim_subclass_ID_list(c));
    
                    [Status_LLM(c), Class_message, Sim_subclass_ID, Call_Token_Usage, LLM_Watchdog(c)] = LLM_Interaction(Status_LLM(c), Message_used, "new_chat", Tartarone.Sim.Classificator, Sim_subclass_ID, LLM_API_Keys, LLM_Watchdog(c));
                    Sim_subclass_ID_list(c) = Sim_subclass_ID;
                    [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update( Token_Usage(c), Call_Token_Usage, "Class");

                    if Status_LLM(c) == 3
                        Subclass_used = Class_message;
                        switch Subclass_used
                            case "SIM_GO"
        
                            case "SIM_STOP"
                                Message_actual(c) = "L'utente ha appena richiesto di fermare la simulazione";
                                Class_list(c).MAIN = "QUESTION";
                                Status_Sim(c) = 0;
                        end
                        Status_LLM(c) = 0;
                        Status_Chat(c) = 3;
                    end
    
                %%% EMS SUBCLASSIFICATION LAYER
                case 5
                    Message_used = Message_actual(c);
                    EMS_subclass_ID = char(EMS_subclass_ID_list(c));
    
                    %%% Classificazione
                    if Single_Stage_LLM_ON && strlength(Class_list(c).EMS) > 0
                        % The leaf class was already produced by the single
                        % LLM call in State 1. No further classifier is called.
                        Class_message = Class_list(c).EMS;
                        Status_LLM(c) = 3;

                    else
                        label = "UNRESOLVED";

                        % Class. Locale
                        if Local_Classifier_ON && Status_LLM(c) == 0
                            label = localEMSClassify(Message_used);
                        end

                        % Class. LLM
                        if label == "UNRESOLVED" && LLM_based_Classifier_ON
                            [Status_LLM(c), Class_message, EMS_subclass_ID, ...
                                Call_Token_Usage, LLM_Watchdog(c)] = ...
                                LLM_Interaction( ...
                                    Status_LLM(c), ...
                                    Message_used, ...
                                    "new_chat", ...
                                    CerBot.EMS.Classificator, ...
                                    EMS_subclass_ID, ...
                                    LLM_API_Keys, ...
                                    LLM_Watchdog(c));

                            [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update( Token_Usage(c), Call_Token_Usage, "Class");
                            EMS_subclass_ID_list(c) = EMS_subclass_ID;

                        elseif label == "UNRESOLVED"
                            Class_message = "EMS_OTHER";
                            Status_LLM(c) = 3;

                        else
                            Class_message = label;
                            Status_LLM(c) = 3;
                        end
                    end

                    %%% Instradamento richieste utente
                    if Status_LLM(c) == 3
                        Subclass_used = Class_message;
                        Class_list(c).EMS = string(Class_message);
                        load(EMS_Agent_Info_name)
    
                        switch Subclass_used
                            case "ADVICE_ON"
                                Instructions = "L'utente ha appena richiesto di attivare l'invio automatico dei consigli di efficentamento. Avvisalo che la modalità consigli automatici è stata attivata";
                                Message_actual(c) = strcat(Message_used, Instructions);
                                Status_EMS(c).Chat_CMD = 1;
                                Status_EMS(c).Advice_ON = 1;
    
                            case "ADVICE_OFF"
                                Instructions = "L'utente ha appena richiesto di sospendere l'invio automatico dei consigli di eficentamento. Avvisalo che la modalità consigli automatici è stata disattivata";
                                Message_actual(c) = strcat(Message_used, Instructions);
                                Status_EMS(c).Chat_CMD = 1;
                                Status_EMS(c).Advice_OFF = 1;
    
                            case "LOAD_PLANNING"
                                Instructions = "L'utente ha appena richiesto di pianificare dei carichi. Chiedi quali e a che ora";
                                Message_actual(c) = strcat(Message_used, Instructions);
                                Status_EMS(c).Chat_CMD = 1;
                                Status_EMS(c).Load_Planning = 1;
    
                            case "AUTO_PLANNING_ON"
                                Instructions = "L'utente ha appena richiesto di attivare la pianificazione automatica dei carichi. Avvisalo che la richiesta è stata presa in carico e che la pianificazione automatica sarà presto attivata";
                                Message_actual(c) = strcat(Message_used, Instructions);
                                Status_EMS(c).Chat_CMD = 1;
                                Status_EMS(c).Auto_Planning_On = 1;
    
                            case "AUTO_PLANNING_OFF"
                                Instructions = "L'utente ha appena richiesto di disattivare la pianificazione automatica dei carichi. Avvisalo che la richiesta è stata presa in carico e che la pianificazione automatica sarà presto sospesa";
                                Status_EMS(c).Chat_CMD = 1;
                                Status_EMS(c).Auto_Planning_Off = 1;
                            case "EMS_OTHER"
                                Instructions = "La richiesta riguarda il sistema EMS ma non corrisponde a nessuna funzionalità attualmente supportata. Chiedi all'utente di riformulare la richiesta.";
                        
                        end
    
                        Message_actual(c) = [...
                            Message_used + newline + ...
                            "<INSTRUCTIONS>" + newline + ...
                            Instructions + newline + ...
                            "</INSTRUCTIONS>"...
                            ];
    
                        save(EMS_Agent_Info_name, "Status_EMS") %Status_Admin_EMS
                        Status_LLM(c) = 0;
                        Status_Chat(c) = 3;
    
                    end
    
                %%% ADMIN SUBCLASSIFICATION LAYER
                % Admin_subclass_ID_old = "";
                % Admin_EMS_subclass_ID_old = "";
                % Admin_Broadcast_subclass_ID_old = "";
                case 6       
                    Message_used = Message_actual(c);
                    ADMIN_subclass_ID = char(Admin_subclass_ID_old);
                    Admin_chat_ID = open_chat_list(c);             

                    %%% Classificazione
                    if Single_Stage_LLM_ON && strlength(Class_list(c).ADMIN) > 0
                        % The admin branch was already identified by the
                        % single-stage classifier.
                        Class_message = Class_list(c).ADMIN;
                        Status_LLM(c) = 3;

                    else
                        label = "UNRESOLVED";

                        % Class. Locale
                        if Local_Classifier_ON && Status_LLM(c) == 0
                            label = local_Admin_Classify(Message_used);
                        end

                        % Class. LLM & check stato broadcast
                        if Admin_Broadcast_Status == 1 && ...
                                string(open_chat_list(c)) == string(Admin_chat_ID)
                            Class_message = "BROADCAST";
                            Status_LLM(c) = 3;

                        elseif label == "UNRESOLVED" && LLM_based_Classifier_ON
                            [Status_LLM(c), Class_message, Class_ID, Call_Token_Usage, LLM_Watchdog(c)] = LLM_Interaction( Status_LLM(c), Message_used, "new_chat", CerBot.Admin.Classificator, ADMIN_subclass_ID, LLM_API_Keys, LLM_Watchdog(c));
                            [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update( Token_Usage(c), Call_Token_Usage, "Class");
                            Admin_subclass_ID_old = Class_ID;

                        elseif label == "UNRESOLVED"
                            Class_message = "CLASSLESS";
                            Status_LLM(c) = 3;

                        else
                            Class_message = label;
                            Status_LLM(c) = 3;
                        end
                    end

                    %%% Gestione cambio e instradamento stati
                    if Status_LLM(c) == 3
                        Subclass_used = Class_message;
                        Class_list(c).ADMIN = string(Class_message);
                        Status_LLM(c) = 0;
    
                        switch Subclass_used
                            case "EMS"
                                Status_Chat(c) = 7;
    
                            case "BROADCAST"
                                Status_Chat(c) = 8;
    
                            case "RESET"
                                previous_ID_list(c) = "new_chat";
                                Status_Chat(c) = 3;
    
                            otherwise
                                Status_Chat(c) = 3;
    
                        end
                        
                    end
    
                %%% ADMIN EMS SUBCLASSIFICATION LAYER
                case 7
                    Message_used = Message_actual(c);
                    Admin_EMS_subclass_ID = char(Admin_EMS_subclass_ID_old);
                      
                    %%% Classificazione
                    if Single_Stage_LLM_ON && strlength(Class_list(c).ADMIN_EMS) > 0
                        % The admin EMS leaf was already produced in State 1.
                        Class_message = Class_list(c).ADMIN_EMS;
                        Status_LLM(c) = 3;

                    else
                        label = "UNRESOLVED";

                        % Class. Locale
                        if Local_Classifier_ON && Status_LLM(c) == 0
                            label = local_Admin_EMS_Classify(Message_used);
                        end

                        % Class. LLM
                        if label == "UNRESOLVED" && LLM_based_Classifier_ON
                            [Status_LLM(c), Class_message, ...
                                Admin_EMS_subclass_ID, ...
                                Call_Token_Usage, LLM_Watchdog(c)] = ...
                                LLM_Interaction( ...
                                    Status_LLM(c), ...
                                    Message_used, ...
                                    "new_chat", ...
                                    CerBot.Admin.EMS.Classificator, ...
                                    Admin_EMS_subclass_ID, ...
                                    LLM_API_Keys, ...
                                    LLM_Watchdog(c));

                            [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update( Token_Usage(c), Call_Token_Usage, "Class");
                            Admin_EMS_subclass_ID_old = Admin_EMS_subclass_ID;

                        elseif label == "UNRESOLVED"
                            Class_message = "EMS_OTHER";
                            Status_LLM(c) = 3;

                        else
                            Class_message = label;
                            Status_LLM(c) = 3;
                        end
                    end

                    %%% Instradamento richieste utente
                    if Status_LLM(c) == 3
                        Subclass_used = Class_message;
                        Class_list(c).ADMIN_EMS = string(Class_message);
                        load(EMS_Agent_Admin_Info_name)
   
                        switch Subclass_used
                            case "ADVICE_COORD_ON"
                                Instructions = "L'Admin ha appena richiesto di attivare l'invio automatico dei consigli di efficentamento. Avvisalo che la modalità consigli automatici è stata attivata";
                                Status_Admin_EMS.Chat_CMD = 1;
                                Status_Admin_EMS.Advice_ON = 1;
    
                            case "ADVICE_COORD_OFF"
                                Instructions = "L'Admin  ha appena richiesto di sospendere l'invio automatico dei consigli di eficentamento. Avvisalo che la modalità consigli automatici è stata disattivata";
                                Status_Admin_EMS.Chat_CMD = 1;
                                Status_Admin_EMS.Advice_OFF = 1;
    
                            case "BESS_COORD_ON"
                                Instructions = "L'Admin ha appena richiesto di attivare il coordinamento automatico degli storages. Avvisalo che tale automatismo è stato attivato";
                                Status_Admin_EMS.Chat_CMD = 1;
                                Status_Admin_EMS.BESS_Coord_On = 1;
    
                            case "BESS_COORD_OFF"
                                Instructions = "L'Admin ha appena richiesto di sospendere il coordinamento automatico degli storages. Avvisalo che tale automatismo è stato disattivato";
                                Status_Admin_EMS.Chat_CMD = 1;
                                Status_Admin_EMS.BESS_Coord_Off = 1;
    
                            case "LOAD_COORD_ON"
                                Instructions = "L'Admin ha appena richiesto di attivare il coordinamento automatico dei carichi. Avvisalo che tale automatismo è stato attivato";
                                Status_Admin_EMS.Chat_CMD = 1;
                                Status_Admin_EMS.Load_Coord_On = 1;
    
                            case "LOAD_COORD_OFF"
                                Instructions = "L'Admin ha appena richiesto di sospendere il coordinamento automatico dei carichi. Avvisalo che tale automatismo è stato disattivato";
                                Status_Admin_EMS.Chat_CMD = 1;
                                Status_Admin_EMS.Load_Coord_Off = 1;

                            case "EMS_OTHER"
                                Instructions = "La richiesta riguarda il sistema EMS ma non corrisponde a nessuna funzionalità attualmente supportata. Chiedi all'utente di riformulare la richiesta.";
                        end
    
                        Message_actual(c) = [...
                            Message_used + newline + ...
                            "<INSTRUCTIONS>" + newline + ...
                            Instructions + newline + ...
                            "</INSTRUCTIONS>"...
                            ];
    
                        save(EMS_Agent_Admin_Info_name, "Status_Admin_EMS")
                        Status_LLM(c) = 0;
                        Status_Chat(c) = 3;
    
                    end
    
                %%% ADMIN BROADCAST Classifier LAYER
                case 8
                    Message_used = Message_actual(c);
                    Admin_Broadcast_subclass_ID = char(Admin_Broadcast_subclass_ID_old);
               
                    %%% Classificazione
                    if Single_Stage_LLM_ON && strlength(Class_list(c).ADMIN_BRD) > 0
                        % The broadcast leaf was already produced in State 1.
                        Class_message = Class_list(c).ADMIN_BRD;
                        Status_LLM(c) = 3;

                    else
                        label = "UNRESOLVED";

                        % Class. Locale
                        if Local_Classifier_ON && Status_LLM(c) == 0
                            label = local_Admin_Broadcast_Classify(Message_used);
                        end

                        % Class. LLM
                        if label == "UNRESOLVED" && LLM_based_Classifier_ON
                            [Status_LLM(c), Class_message, ...
                                Admin_Broadcast_subclass_ID, ...
                                Call_Token_Usage, LLM_Watchdog(c)] = ...
                                LLM_Interaction( ...
                                    Status_LLM(c), ...
                                    Message_used, ...
                                    "new_chat", ...
                                    CerBot.Admin.BROAD.Classificator, ...
                                    Admin_Broadcast_subclass_ID, ...
                                    LLM_API_Keys, ...
                                    LLM_Watchdog(c));

                            [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update( Token_Usage(c), Call_Token_Usage, "Class");
                            Admin_Broadcast_subclass_ID_old = ...
                                Admin_Broadcast_subclass_ID;

                        elseif label == "UNRESOLVED"
                            Class_message = "MSG_OTHER";
                            Status_LLM(c) = 3;

                        else
                            Class_message = label;
                            Status_LLM(c) = 3;
                        end
                    end

                    %%% Instradamento richieste utente
                    if Status_LLM(c) == 3
                        Subclass_used = Class_message;
                        Class_list(c).ADMIN_BRD = string(Class_message);
                        Status_LLM(c) = 0;
    
                        switch Subclass_used
                            case "MSG_NOT_READY"
                                Instructions = "L'Admin vuole contattare i membri della CER, ma non ha ancora specificato il contenuto del messaggio. " + ...
                                    "Rispondi chiedendo solo quale messaggio vuole inviare. " + ...
                                    "Non chiedere canali, destinatari, allegati, priorità, frequenza, orario o altri dettagli.";
                                Message_actual(c) = [...
                                    Message_used + newline + ...
                                    "<INSTRUCTIONS>" + newline + ...
                                    Instructions + newline + ...
                                    "</INSTRUCTIONS>"...
                                    ];
                                Admin_Broadcast_Status = 1;
                                Status_Chat(c) = 3;
    
                            case "MSG_READY"
                                Status_Chat(c) = 9;
    
                            case "MSG_ABORT"
                                Instructions = " INSTRUCTIONS: L'Admin ha deciso che vuole sospendere il broadcast. Avvisalo che la richiesta è stata annullata correttamente";
                                Message_actual(c) = strcat(Message_used, Instructions);
                                Admin_Broadcast_Status = 0;
                                Status_Chat(c) = 3;

                            case "MSG_OTHER"
                                Instructions = "La richiesta relativa al broadcast non è chiara. Chiedi al amministratore di riformularla.";
                                Message_actual(c) = [...
                                    Message_used + newline + ...
                                    "<INSTRUCTIONS>" + newline + ...
                                    Instructions + newline + ...
                                    "</INSTRUCTIONS>"...
                                    ];
                                Status_Chat(c) = 3;    
                        end
    
                    end
    
                %%% ADMIN Broadcast message extraction LAYER
                case 9
                    Message_used = Message_actual(c);
                    Admin_Broadcast_subclass_ID = char(Admin_Broadcast_subclass_ID_old);
    
                    % Se classificatore locale fallisce lancia LLM
                    [Status_LLM(c), Admin_Broadcast_message, Admin_Broadcast_subclass_ID, Call_Token_Usage, LLM_Watchdog(c)] = LLM_Interaction(Status_LLM(c), Message_used, "new_chat", CerBot.Admin.BROAD.Message, Admin_Broadcast_subclass_ID, LLM_API_Keys, LLM_Watchdog(c));
                    [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update(Token_Usage(c), Call_Token_Usage, "Answer");
                    Admin_Broadcast_subclass_ID_old = Admin_Broadcast_subclass_ID;
                    
                    %%% Instradamento richieste utente
                    if Status_LLM(c) == 3
                        % Answer_list(c) = strcat("Il broadcast è stato avviato correttamente. Sarà inviato il seguente messaggio: ",Admin_Broadcast_message);
                        if ~Classification_Test_ON
                            Status_Chat(c) = 0;
                            Status_LLM(c) = 0;
                            %%%% SET UP BROADCAST %%%%
                            [broadBegin, broadMessage, broadEnd] = parseBroadcastResponse(Admin_Broadcast_message);
                            Users_chats_ID_check = open_chat_list ~= Admin_chat_ID;
                            n_msg_to_send = n_chat_open + 1;
        
                            % Messaggi e ID utenti comuni
                            Broadcast_Users_ID_List = open_chat_list(Users_chats_ID_check);
                            Broadcast_Message_List(1:n_msg_to_send) = broadMessage;
        
                            % Messaggio e ID Amministratore
                            Answer_list(c) = broadBegin;
                            Starting_Broadcast_msg = broadBegin;
                            Ending_Broadcast_msg = broadEnd;
        
                            Broadcast_Message_List(1) = Starting_Broadcast_msg;
                            Broadcast_Message_List(end) = Ending_Broadcast_msg;
                            Broadcast_Users_ID_List = [Admin_chat_ID Broadcast_Users_ID_List Admin_chat_ID];
        
                            Admin_Broadcast_Status = 2;
                            save Broadcast_Info.mat Broadcast_Users_ID_List Broadcast_Message_List
        
                            last_update_list(c) = Update_ID_actual(c);

                        else
                            Status_Chat(c) = 100;

                        end
                    end
    
                %%% ANSWER GENERATION    
                case 3
                    Message_used = Message_actual(c);
                    previous_ID = char(previous_ID_list(c));
                    Answer_ID = char(Answer_ID_list(c));
                    Class_used = Class_list(c).MAIN;
    
                    [Status_LLM(c), Answer_message, Answer_ID, Call_Token_Usage, LLM_Watchdog(c)] = CerBot_Decision_Three(Class_used, Status_LLM(c), Message_used, previous_ID, CerBot, Answer_ID, LLM_API_Keys, LLM_Watchdog(c), Classification_Test_ON);                   
                    [Token_Usage(c), Call_Token_Usage] = Token_Usage_Update(Token_Usage(c), Call_Token_Usage, "Answer");
                    Answer_ID_list(c) = Answer_ID;
            
                    if Status_LLM(c) == 3
                        Answer_list(c) = string(Answer_message);
                        previous_ID_list(c) = Answer_ID;
                        Status_LLM(c) = 0;
                        Status_Chat(c) = 4;
                    end
    
                 %%% ANSWER SENDING
                case 4 
                    chat_used = open_chat_list(c);
    
                    if ~Classification_Test_ON
                        %%% Se la simulazione è attiva non aggiorno l'ID
                        %%% dell'ultimo messaggio da Telegram
                        if Status_Sim(c) == 3
                        else
                            last_update_list(c) = Update_ID_actual(c);
                        end

                        %%% API call
                        message = Answer_list(c);
                        if ~strcmp(message,"")
                            [response] = Send_Messages_to_Chat(message, chat_used, Telegram_token, HMI_choice);
                            %%% Update of the status variables    
                            previous_ID_list(c) = Answer_ID_list(c);
                        end
                        %%% Return to starting State 
                        Status_Chat(c) = 0;

                    else
                        %%% Go to the final test stage 
                        Status_Chat(c) = 100;
                    end
                    
                %%% Test final stage
                case 100 
                    last_update_list(c) = Update_ID_actual(c);
                    Dataset_Token_Usage(D) = Token_Usage(c);
                    Dataset_Latency(D) = toc(msg_tstart{c});
                    save(Dataset_Results_name, "Dataset_Latency", "Dataset_Token_Usage", "D", "datasetsize")
                    D = D+1;
                    if D>datasetsize
                        cycle_on = 0;
                    end
                    %%% Return to starting State 
                    Status_Chat(c) = 0;
                    
                end
    
                % catch
                %     dt = datetime("now");
                %     s  = datestr(dt,'yyyy/mm/dd HH:MM:SS');
                %     disp(strcat(s, " -> problem with the user: ",string(open_chat_list(c)))) 
                % end
    
                
            end
        
            %% salvataggio dello stato delle conversazioni
            Conversation_Status_Saving
    
            %% Amministrazione delle Simulazioni
            % CER_Simulator_Administrator;
        end    
    
        %% BROADCAST
        if ~Classification_Test_ON
            if Admin_Broadcast_Status == 2
                load Broadcast_Info.mat
                n_msg_broadcast = max(size(Broadcast_Message_List));
                for c=1:n_msg_broadcast
                    %%% API call
                        chat_used = Broadcast_Users_ID_List(c);
                        message   = Broadcast_Message_List(c);
                        if ~strcmp(message,"")
                            [response] = Send_Messages_to_Chat(message, chat_used, Telegram_token, HMI_choice);
                            %%% Update of the status variables    
                        end
                end
                Admin_Broadcast_Status = 0;
            end
            Conversation_Status_Saving    
        
            % %% Msg_from EMS
            % %load EMS_Agent_Info_exchange.mat
            % load(EMS_Agent_Info_name)
            % 
            % Array_msg_req = [Status_EMS.Message_Req];
            % Array_msg_req_index = find(Array_msg_req,max(n_chat_open,1));
            % for c=Array_msg_req_index
            %     %%% API call
            %         chat_used = Broadcast_Users_ID_List(c);
            %         message   = Broadcast_Message_List(c);
            %         if ~strcmp(message,"")
            %             [response] = Send_Messages_to_Chat(message, chat_used, Telegram_token, HMI_choice);
            %             %%% Update of the status variables    
            %         end
            % end
            % 
            % Conversation_Status_Saving    
            % % catch
            % %     disp(strcat(datestr(now, 'dd-mmm-yyyy HH:MM:SS'), ': WARNING'));
            % % % 
            % % end
            % disp([Status_Chat; Status_LLM])
        end
    
        catch ME
            % Stampa il messaggio completo dell'errore
            disp(getReport(ME, 'extended'));
        pause(1)   
    end
end

    fprintf('Completed configuration: %s\n', Classificator_label);
end % Config_Index

%% ================================================================
%  LOCAL FUNCTIONS - TEST RUNNER ONLY
% ================================================================
function [Resolved, Out_Class_list] = Try_Local_Full_Tree( ...
    Message, Class_list_Template, Admin_Broadcast_Status, ...
    Current_Chat_ID, Admin_chat_ID)
%TRY_LOCAL_FULL_TREE Attempts the complete deterministic classifier tree.
%
% A local decision is accepted only if a COMPLETE route can be produced.
% If any required local layer returns UNRESOLVED (or an empty label), the
% function returns Resolved=false and H-Single delegates the original
% message to the Single-Stage LLM.

    Resolved = false;
    Out_Class_list = Class_list_Template;

    Message = string(Message);
    Wrapped_Message = [ ...
        "<MESSAGE>" + newline + ...
        Message + newline + ...
        "</MESSAGE>" ...
        ];

    % Active multi-turn admin broadcast: reproduce the routing context used
    % by the Single-Stage branch and directly attempt the broadcast leaf.
    if Admin_Broadcast_Status == 1 && ...
            string(Current_Chat_ID) == string(Admin_chat_ID)

        Broadcast_Label = string(local_Admin_Broadcast_Classify(Wrapped_Message));
        if Is_Resolved_Local_Label(Broadcast_Label)
            Out_Class_list.MAIN = "ADMIN";
            Out_Class_list.ADMIN = "BROADCAST";
            Out_Class_list.ADMIN_BRD = Broadcast_Label;
            Resolved = true;
        end
        return
    end

    Main_Label = string(local_first_layer_Classify(Message));
    if ~Is_Resolved_Local_Label(Main_Label)
        return
    end

    switch Main_Label
        case "EMS"
            EMS_Label = string(localEMSClassify(Wrapped_Message));
            if ~Is_Resolved_Local_Label(EMS_Label)
                return
            end

            Out_Class_list.MAIN = "EMS";
            Out_Class_list.EMS = EMS_Label;
            Resolved = true;

        case "ADMIN"
            Admin_Label = string(local_Admin_Classify(Wrapped_Message));
            if ~Is_Resolved_Local_Label(Admin_Label)
                return
            end

            Out_Class_list.MAIN = "ADMIN";
            Out_Class_list.ADMIN = Admin_Label;

            switch Admin_Label
                case "EMS"
                    Admin_EMS_Label = string(local_Admin_EMS_Classify(Wrapped_Message));
                    if ~Is_Resolved_Local_Label(Admin_EMS_Label)
                        Out_Class_list = Class_list_Template;
                        return
                    end
                    Out_Class_list.ADMIN_EMS = Admin_EMS_Label;
                    Resolved = true;

                case "BROADCAST"
                    Broadcast_Label = string(local_Admin_Broadcast_Classify(Wrapped_Message));
                    if ~Is_Resolved_Local_Label(Broadcast_Label)
                        Out_Class_list = Class_list_Template;
                        return
                    end
                    Out_Class_list.ADMIN_BRD = Broadcast_Label;
                    Resolved = true;

                otherwise
                    % ADMIN_START, RESET, QUESTION-like routes, CHANGE,
                    % SIMULATION, INSULT, CLASSLESS are complete at this layer.
                    Resolved = true;
            end

        otherwise
            % START, RESET, CHANGE, SIMULATION, INSULT, CLASSLESS, etc.
            Out_Class_list.MAIN = Main_Label;
            Resolved = true;
    end
end

function [Resolved, Out_Class_list] = Try_Local_Selective_Tree( ...
    Message, Class_list_Template, Admin_Broadcast_Status, ...
    Current_Chat_ID, Admin_chat_ID, Trusted_Classes)
%TRY_LOCAL_SELECTIVE_TREE Conservative local gate used by HS-Single.
%
% The deterministic tree is allowed to classify the message only when:
%   1) it reaches a complete final route; and
%   2) the final class is included in Trusted_Classes.
%
% Otherwise Resolved remains false and the original message is delegated to
% the Single-Stage LLM. No partial local route is retained.

    Resolved = false;
    Out_Class_list = Class_list_Template;

    [Tree_Resolved, Candidate_Class_list] = Try_Local_Full_Tree( ...
        Message, ...
        Class_list_Template, ...
        Admin_Broadcast_Status, ...
        Current_Chat_ID, ...
        Admin_chat_ID);

    if ~Tree_Resolved
        return
    end

    Final_Label = Get_Final_Route_Label(Candidate_Class_list);

    if any(Final_Label == string(Trusted_Classes))
        Out_Class_list = Candidate_Class_list;
        Resolved = true;
    end
end

function Final_Label = Get_Final_Route_Label(Class_list)
%GET_FINAL_ROUTE_LABEL Returns the final externally evaluated class.

    Main_Label = string(Class_list.MAIN);

    switch Main_Label
        case "EMS"
            Final_Label = string(Class_list.EMS);

        case "ADMIN"
            Admin_Label = string(Class_list.ADMIN);

            switch Admin_Label
                case "EMS"
                    Final_Label = string(Class_list.ADMIN_EMS);

                case "BROADCAST"
                    Final_Label = string(Class_list.ADMIN_BRD);

                otherwise
                    Final_Label = Admin_Label;
            end

        otherwise
            Final_Label = Main_Label;
    end
end

function tf = Is_Resolved_Local_Label(Label)
    Label = string(Label);
    tf = strlength(Label) > 0 && Label ~= "UNRESOLVED";
end



