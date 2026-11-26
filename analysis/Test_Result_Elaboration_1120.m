%% Elaborazione risultati degli esperimenti
% Richiede Classification_Dataset_Setup ed evaluateClassifierConfusionMatrix.
% Elabora solo i risultati salvati: non esegue nuovi esperimenti o chiamate API.

% Percorso relativo allo script, indipendente dalla cartella corrente.
Script_Folder = fileparts(mfilename('fullpath'));
Results_Folder = fullfile(Script_Folder, "Results");
if ~isfolder(Results_Folder)
    Results_Folder = fullfile(Script_Folder, "Classification Test", "Results");
end
if isfolder(Results_Folder)
    addpath(Results_Folder)
end
Output_Folder = pwd;

%% Caricamento Dataset
% Il dataset nel nome del run ha precedenza su quello predefinito.
Dataset_Default = "ChatGPT";
Dataset_list = ["ChatGPT", "Claude", "Grok", "DeepSeek"];
External_Datasets = ["Grok", "DeepSeek", "Claude"];

%%% Classi disponibili, nello stesso ordine dello script originale
classNames = ["START", "RESET", "QUESTION", "CHANGE", ...
    "SIMULATION", "INSULT", "ADVICE_ON", "ADVICE_OFF", ...
    "LOAD_PLANNING", "AUTO_PLANNING_ON", "AUTO_PLANNING_OFF", ...
    "BESS_COORD_ON", "BESS_COORD_OFF", "LOAD_COORD_ON", ...
    "LOAD_COORD_OFF", "ADVICE_COORD_ON", "ADVICE_COORD_OFF", ...
    "MSG_ABORT", "CLASSLESS", "EMS_OTHER", "MSG_NOT_READY", "MSG_READY", "MSG_OTHER"];

%%% Lista classificatori
% Aggiungere qui i prefissi dei file, senza estensione o suffissi di salvataggio.
% Non esiste un elenco chiuso di architetture o modelli riconosciuti.
% Esempi: "NuovoMetodo_nuovoModello_low_Claude", "TFIDF_nano_low_Claude".
% Il token del dataset puo precedere o seguire R2, R3, ecc.
% I run senza token di dataset usano Dataset_Default.
Classificator_list = ["Local_old", "Local_freeze", "Local_freeze2", ...
                      "LLM_nano_low_nocatch", "LLM_luna_low", "LLM_sol_low", "LLM_nano_low",  "LLM_nano_high", "LLM_luna_high", "LLM_sol_high", ...
                      "Hybrid_nano_low_nocatch", "Hybrid_nano_low", "Hybrid_luna_low", "Hybrid_sol_low", "Hybrid_nano_high", "Hybrid_luna_high", "Hybrid_sol_high", ...
                      "Single_nano_high_nocatch", "Single_nano_high","Single_nano_low","Single_luna_high", "Single_sol_high", "Single_luna_low", "Single_sol_low", "Single_sol_high_R2", "Single_luna_low_R2", "Single_sol_low_R2",...
                      "HSingle_luna_low", "HSSingle_luna_low", ...
                      "Single_luna_low_Grok", "HSingle_luna_low_Grok", "HSSingle_luna_low_Grok", ...
                      "Single_luna_low_DeepSeek", "HSingle_luna_low_DeepSeek", "HSSingle_luna_low_DeepSeek", ...
                      "Single_luna_low_Claude", "HSingle_luna_low_Claude", "HSSingle_luna_low_Claude", ...
                      "Single_nano_low_Grok", "HSingle_nano_low_Grok", "HSSingle_nano_low_Grok", ...
                      "Single_nano_low_DeepSeek", "HSingle_nano_low_DeepSeek", "HSSingle_nano_low_DeepSeek", ...
                      "Single_nano_low_Claude", "HSingle_nano_low_Claude", "HSSingle_nano_low_Claude", ...
                      "HSingle_nano_low", "HSSingle_nano_low", ...
                      "Single_haiku_low_Grok", "HSingle_haiku_low_Grok", "HSSingle_haiku_low_Grok", ...
                      "Single_haiku_low_DeepSeek", "HSingle_haiku_low_DeepSeek", "HSSingle_haiku_low_DeepSeek", ...
                      "Single_haiku_low_Claude", "HSingle_haiku_low_Claude", "HSSingle_haiku_low_Claude", ...
                      "Single_haiku_low", "HSingle_haiku_low", "HSSingle_haiku_low", ...
                      "TFIDF_nano_low", "TFIDF_nano_low_DeepSeek", "TFIDF_nano_low_Grok", "TFIDF_nano_low_Claude", ...
                      "MiniLM_nano_low", "MiniLM_nano_low_DeepSeek", "MiniLM_nano_low_Grok", "MiniLM_nano_low_Claude"];

N_Classificator = numel(Classificator_list);
Result_Fields = matlab.lang.makeUniqueStrings( ...
    matlab.lang.makeValidName(cellstr(Classificator_list)));
Classification_results_Test = struct();
Message_Tables = cell(N_Classificator, 1);
Summary_Tables = cell(N_Classificator, 1);

Class_Label_Map = struct();
Class_Label_Map.index = (1:numel(classNames))';
Class_Label_Map.name = cellstr(classNames(:));
Class_Label_Map.is_target = ~ismember(classNames(:), ...
    ["MSG_ABORT", "CLASSLESS", "EMS_OTHER", "MSG_OTHER"]);

%% Risultati Simulazione
for C = 1:N_Classificator
    Classificator = Classificator_list(C);
    Result_Field = Result_Fields{C};

    %%% Dataset e gruppo di confronto ricavati dal nome del run
    % Il gruppo e il nome completo senza il solo token del dataset.
    % Modello, effort, varianti e ripetizioni restano quindi distinti.
    Name_Parts = split(Classificator, "_");
    Dataset_Position = find(ismember(Name_Parts, Dataset_list), 1, 'last');
    Dataset = Dataset_Default;
    if ~isempty(Dataset_Position)
        Dataset = Name_Parts(Dataset_Position);
        Name_Parts(Dataset_Position) = [];
    end
    Group = join(Name_Parts, "_");

    % Metadati descrittivi secondo la convenzione nome_modello_effort_variante.
    % I nomi nuovi vengono comunque elaborati, senza richiedere nuovi case.
    Metadata_Parts = Name_Parts;
    Replicate = "R1";
    Position = find(~cellfun('isempty', regexp(cellstr(Metadata_Parts), '^R\d+$', 'once')), 1, 'last');
    if ~isempty(Position)
        Replicate = Metadata_Parts(Position);
        Metadata_Parts(Position) = [];
    end
    Strategy = Metadata_Parts(1);
    switch Strategy
        case "HSingle"
            Strategy = "H-Single";
        case "HSSingle"
            Strategy = "HS-Single";
        case "LLM"
            Strategy = "Hierarchical LLM";
    end
    Model = Metadata_Parts(1);
    Effort = "";
    Variant = "";
    if Metadata_Parts(1) == "Local"
        Model = "rules";
        Variant = join(Metadata_Parts(2:end), "_");
    else
        if numel(Metadata_Parts) >= 2 && ~ismember(Metadata_Parts(1), ["TFIDF", "MiniLM"])
            Model = Metadata_Parts(2);
        end
        if numel(Metadata_Parts) >= 3
            Effort = Metadata_Parts(3);
        end
        if numel(Metadata_Parts) >= 4
            Variant = join(Metadata_Parts(4:end), "_");
        end
    end
    Model_Parts = [Model; Effort; Variant];
    Model_Key = join(Model_Parts(strlength(Model_Parts) > 0), "_");

    [datasetsize, Dataset_Message_list, Dataset_Update_ID_list, ...
        Dataset_chat_ID_list, Correct_Class_list] = Classification_Dataset_Setup(Dataset);
    Correct_Class_list = normalizeLabels(Correct_Class_list, classNames);

    % Solo il nome del file: load cerca anche nelle cartelle del path MATLAB.
    Conversation_Status_name  = Classificator + "_conversation_status_CerBot_test.mat";
    EMS_Agent_Info_name       = Classificator + "_EMS_Agent_Info_exchange_test.mat";
    EMS_Agent_Admin_Info_name = Classificator + "_EMS_Agent_Admin_Info_exchange_test.mat";
    Dataset_Results_name      = Classificator + "_Dataset_Result_Test.mat";

    %%% Caricamento dei risultati in strutture separate
    Conversation = load(Conversation_Status_name);
    Results = load(Dataset_Results_name);
    Class_list = Conversation.Class_list;
    Dataset_Latency = Results.Dataset_Latency;
    Dataset_Token_Usage = Results.Dataset_Token_Usage;

    if numel(Dataset_Latency) ~= datasetsize || numel(Dataset_Token_Usage) ~= datasetsize
        error('Il run %s non contiene %d risultati completi.', Classificator, datasetsize)
    end

    %%% Associazione fra messaggi del dataset e chat salvate
    % Class_list e indicizzato per chat; latenza e token per messaggio.
    Chat_Order = (1:datasetsize)';
    Alignment = "dataset_order_assumed";
    if numel(unique(string(Dataset_chat_ID_list(:)))) ~= datasetsize
        error('Il dataset %s riusa una chat: lo stato finale non ricostruisce ogni messaggio.', Dataset)
    end
    if isfield(Conversation, 'open_chat_list')
        Saved_Chat_IDs = string(Conversation.open_chat_list(:));
        if numel(Saved_Chat_IDs) ~= numel(Class_list) || numel(unique(Saved_Chat_IDs)) ~= numel(Saved_Chat_IDs)
            error('La lista delle chat del run %s e incoerente con Class_list.', Classificator)
        end
        [Chat_Found, Chat_Order] = ismember( ...
            string(Dataset_chat_ID_list(:)), Saved_Chat_IDs);
        if ~all(Chat_Found)
            error('Nel run %s mancano chat presenti nel dataset %s.', Classificator, Dataset)
        end
        Alignment = "chat_id";
    elseif numel(Class_list) ~= datasetsize
        error('Class_list del run %s non coincide con la dimensione del dataset.', Classificator)
    end

    %%% Ordinamento Risultati, con la stessa logica dello script originale
    Class_Result = repmat("", datasetsize, 1);
    Route_Fields = {'MAIN', 'EMS', 'ADMIN', 'ADMIN_EMS', 'ADMIN_BRD'};
    Routes = strings(datasetsize, numel(Route_Fields));
    for D = datasetsize:-1:1
        Chat = Chat_Order(D);
        for K = 1:numel(Route_Fields)
            Routes(D,K) = string(Class_list(Chat).(Route_Fields{K}));
        end
        Class_Result(D) = Class_list(Chat).MAIN;
        switch Class_Result(D)
            case "EMS"
                Class_Result(D) = Class_list(Chat).EMS;
            case "ADMIN"
                Class_Result(D) = Class_list(Chat).ADMIN;
                switch Class_Result(D)
                    case "EMS"
                        Class_Result(D) = Class_list(Chat).ADMIN_EMS;
                    case "BROADCAST"
                        Class_Result(D) = Class_list(Chat).ADMIN_BRD;
                end
        end
    end
    Class_Result = normalizeLabels(Class_Result, classNames);
    [~, True_Index] = ismember(Correct_Class_list, classNames);
    [~, Pred_Index] = ismember(Class_Result, classNames);

    %%% Informazioni per ogni messaggio
    Records = struct();
    Records.dataset = repmat({char(Dataset)}, datasetsize, 1);
    Records.sample_id = cellstr(string((1:datasetsize)'));
    Records.run_id = repmat({char(Classificator)}, datasetsize, 1);
    Records.group = repmat({char(Group)}, datasetsize, 1);
    Records.model = repmat({char(Model_Key)}, datasetsize, 1);
    Records.model_alias = repmat({char(Model)}, datasetsize, 1);
    Records.strategy = repmat({char(Strategy)}, datasetsize, 1);
    Records.effort = repmat({char(Effort)}, datasetsize, 1);
    Records.replicate = repmat({char(Replicate)}, datasetsize, 1);
    Records.variant = repmat({char(Variant)}, datasetsize, 1);
    Records.text = cellstr(string(Dataset_Message_list(:)));
    Records.update_id = cellstr(string(Dataset_Update_ID_list(:)));
    Records.chat_id = cellstr(string(Dataset_chat_ID_list(:)));
    Records.true_label = cellstr(Correct_Class_list);
    Records.pred_label = cellstr(Class_Result);
    Records.true_label_index = True_Index(:);
    Records.pred_label_index = Pred_Index(:);
    Records.is_correct = Correct_Class_list == Class_Result;
    % Dataset_Latency misura il workflow del messaggio, non il solo classificatore.
    Records.latency_s = double(Dataset_Latency(:));
    for K = 1:numel(Route_Fields)
        Records.(lower(Route_Fields{K})) = cellstr(Routes(:,K));
    end

    %%% Token extraction
    % Classifier e Answer sono componenti separate.
    % Last e l'ultima chiamata; Cumulative e il cumulato della chat.
    % I quattro blocchi si sovrappongono: NON vanno sommati fra loro.
    Token_Scopes = {'Classifier', 'Answer', 'Last', 'Cumulative'};
    Token_Fields = {'Input', 'Input_Ordinary', 'Input_Cached', ...
        'Input_Cache_Write', 'Output', 'Output_Reasoning', 'Total'};
    Token_Prefixes = {'', 'Answer_', 'Last_', 'Cumulative_'};
    for S = 1:numel(Token_Scopes)
        for K = 1:numel(Token_Fields)
            Values = nan(datasetsize, 1);
            for D = 1:datasetsize
                if isfield(Dataset_Token_Usage(D), Token_Scopes{S})
                    Usage = Dataset_Token_Usage(D).(Token_Scopes{S});
                    if isfield(Usage, Token_Fields{K})
                        Values(D) = double(Usage.(Token_Fields{K}));
                    end
                end
            end
            Field = [Token_Prefixes{S}, Token_Fields{K}, '_Tokens'];
            Records.(Field) = Values;
        end
    end
    % Un dato assente resta NaN. Zero indica un conteggio effettivamente nullo.
    Known_Usage = isfinite(Records.Input_Tokens) & isfinite(Records.Output_Tokens);
    Records.classifier_has_tokens = nan(datasetsize, 1);
    Records.classifier_has_tokens(Known_Usage) = ...
        Records.Input_Tokens(Known_Usage) > 0 | Records.Output_Tokens(Known_Usage) > 0;

    %%% Stati finali e watchdog, nell'ordine dei messaggi del dataset
    State_Fields = {'Status_Chat', 'Status_LLM', 'Status_Sim', 'last_update_list'};
    Record_Fields = {'status_chat', 'status_llm', 'status_sim', 'last_update'};
    for K = 1:numel(State_Fields)
        Values = nan(datasetsize, 1);
        if isfield(Conversation, State_Fields{K})
            Saved_Values = Conversation.(State_Fields{K});
            Values = double(reshape(Saved_Values(Chat_Order), [], 1));
        end
        Records.(Record_Fields{K}) = Values;
    end
    Watchdog_Fields = {'Retry_Count', 'Timeout', 'Max_Retry'};
    Record_Fields = {'final_retry_count', 'timeout_s', 'max_retry'};
    for K = 1:numel(Watchdog_Fields)
        Values = nan(datasetsize, 1);
        if isfield(Conversation, 'LLM_Watchdog')
            for D = 1:datasetsize
                Item = Conversation.LLM_Watchdog(Chat_Order(D));
                if isfield(Item, Watchdog_Fields{K})
                    Values(D) = double(Item.(Watchdog_Fields{K}));
                end
            end
        end
        Records.(Record_Fields{K}) = Values;
    end
    % Retry_Count e lo stato finale del watchdog, non il totale storico dei retry.
    Text_Fields = {'Message_actual', 'Answer_list'};
    Record_Fields = {'final_message', 'final_answer'};
    for K = 1:numel(Text_Fields)
        Values = strings(datasetsize, 1);
        if isfield(Conversation, Text_Fields{K})
            Saved_Values = string(Conversation.(Text_Fields{K}));
            Values = reshape(Saved_Values(Chat_Order), [], 1);
        end
        Records.(Record_Fields{K}) = cellstr(Values);
    end
    % Message_actual puo gia contenere istruzioni aggiunte: non sostituisce text.

    %%% Stati EMS salvati
    % Lo stato amministratore e condiviso e resta uno snapshot del run.
    % I flag EMS utente sono associati ai messaggi solo se esiste uno stato per chat.
    Status_EMS = [];
    Status_Admin_EMS = [];
    Source_Files = {char(Conversation_Status_name); char(Dataset_Results_name)};
    if exist(char(EMS_Agent_Info_name), 'file') == 2
        EMS_Data = load(EMS_Agent_Info_name, 'Status_EMS');
        Status_EMS = EMS_Data.Status_EMS;
        Source_Files{end+1,1} = char(EMS_Agent_Info_name);
        EMS_Fields = fieldnames(Status_EMS);
        if numel(Status_EMS) == numel(Class_list)
            for K = 1:numel(EMS_Fields)
                Values = nan(datasetsize, 1);
                for D = 1:datasetsize
                    Value = Status_EMS(Chat_Order(D)).(EMS_Fields{K});
                    if (isnumeric(Value) || islogical(Value)) && isscalar(Value)
                        Values(D) = double(Value);
                    end
                end
                Records.(['ems_', lower(EMS_Fields{K})]) = Values;
            end
        end
    end
    if exist(char(EMS_Agent_Admin_Info_name), 'file') == 2
        EMS_Data = load(EMS_Agent_Admin_Info_name, 'Status_Admin_EMS');
        Status_Admin_EMS = EMS_Data.Status_Admin_EMS;
        Source_Files{end+1,1} = char(EMS_Agent_Admin_Info_name);
    end

    %%% Metriche di classificazione e informazioni complessive
    Evaluation = evaluateClassifierConfusionMatrix( ...
        Correct_Class_list, Class_Result, classNames, "", Classificator, [0,0,0,0]);
    Summary = summarizeExperiment(Records, classNames, Class_Label_Map.is_target);
    Classification_results = struct();
    Classification_results.(Result_Field) = Evaluation;
    % Mantiene i campi totali dello script originale allo stesso livello.
    Summary_Fields = fieldnames(Summary);
    for K = 1:numel(Summary_Fields)
        Classification_results.(Summary_Fields{K}) = Summary.(Summary_Fields{K});
    end
    Classification_results.Dataset = char(Dataset);
    Classification_results.Run_Name = char(Classificator);
    Classification_results.Group = char(Group);
    Classification_results.Alignment = char(Alignment);
    Classification_results.Class_Names = cellstr(classNames(:));
    Classification_results.Class_Label_Map = Class_Label_Map;
    Classification_results.Ground_Truth_Source = 'Classification_Dataset_Setup';
    Classification_results.Metadata_Source = 'run filename; aliases, not API model IDs';
    Classification_results.Source_Files = Source_Files;
    Classification_results.Per_Message = Records;
    Classification_results.Dataset_Token_Usage = Dataset_Token_Usage;
    Classification_results.Status_EMS = Status_EMS;
    Classification_results.Status_Admin_EMS = Status_Admin_EMS;
    Final_Fields = {'Admin_Broadcast_Status', 'Admin_chat_ID', 'n_chat_open', ...
        'Status_Chat', 'Status_LLM', 'Status_Sim', 'LLM_Watchdog'};
    Classification_results.Final_State = struct();
    for K = 1:numel(Final_Fields)
        if isfield(Conversation, Final_Fields{K})
            Classification_results.Final_State.(Final_Fields{K}) = Conversation.(Final_Fields{K});
        end
    end
    if isfield(Results, 'D')
        Classification_results.Saved_Progress_D = Results.D;
    end
    if isfield(Results, 'datasetsize')
        Classification_results.Declared_Sample_Count = Results.datasetsize;
    end
    Classification_results_Test.(Result_Field) = Classification_results;
    Message_Tables{C} = struct2table(Records);
    Summary_Tables{C} = summaryTable(Classificator, Dataset, Group, Summary);
    fprintf('Elaborato %s: %s, %d messaggi.\n', Classificator, Dataset, datasetsize)
end

save(fullfile(Output_Folder, 'Classification_results_Test.mat'), ...
    'Classification_results_Test', 'Class_Label_Map', '-v7');
All_Messages = concatenateTables(Message_Tables);
All_Summaries = vertcat(Summary_Tables{:});
writetable(All_Messages, fullfile(Output_Folder, 'Classification_records_Test.csv'), 'Encoding', 'UTF-8');
writetable(All_Summaries, fullfile(Output_Folder, 'Classification_summary_Test.csv'), 'Encoding', 'UTF-8');

%% Valutazione aggregata sui dataset esterni, per tutti i classificatori
% I gruppi sono ricavati dalla lista: aggiungere un modello non richiede altro codice.
% Ripetizioni/effort/varianti diversi non vengono uniti nello stesso gruppo.
% Sono usati solo i dataset presenti; Dataset_Sources ne conserva l'elenco esatto.
Combined_plot_ON = [0,0,0,0];
Combined_External_Test_Results = struct();
Combined_Summaries = {};
Groups = unique(string(All_Messages.group), 'stable');
Group_Fields = matlab.lang.makeUniqueStrings( ...
    matlab.lang.makeValidName(cellstr(Groups)));
for A = 1:numel(Groups)
    Group = Groups(A);
    Selected = string(All_Messages.group) == Group & ...
        ismember(string(All_Messages.dataset), External_Datasets);
    Combined = All_Messages(Selected,:);
    if isempty(Combined)
        continue
    end
    Dataset_Sources = unique(string(Combined.dataset), 'stable');
    % Due run dello stesso dataset non vanno contati due volte nello stesso gruppo.
    Sample_Keys = string(Combined.dataset) + ":" + string(Combined.sample_id);
    if numel(unique(Sample_Keys)) ~= height(Combined)
        error('Il gruppo %s contiene run duplicati sullo stesso dataset: distinguere le ripetizioni nel nome.', Group)
    end
    Combined_Result = evaluateClassifierConfusionMatrix( ...
        string(Combined.true_label), string(Combined.pred_label), classNames, ...
        "External test sets: " + join(Dataset_Sources, " + "), Group, Combined_plot_ON);
    Records = table2struct(Combined, 'ToScalar', true);
    Summary = summarizeExperiment(Records, classNames, Class_Label_Map.is_target);
    Combined_Entry = struct();
    Combined_Entry.Evaluation = Combined_Result;
    Summary_Fields = fieldnames(Summary);
    for K = 1:numel(Summary_Fields)
        Combined_Entry.(Summary_Fields{K}) = Summary.(Summary_Fields{K});
    end
    Combined_Entry.Group = char(Group);
    Combined_Entry.Dataset_Sources = cellstr(Dataset_Sources);
    Combined_Entry.Complete_External_Set = all(ismember(External_Datasets, Dataset_Sources));
    Combined_Entry.Run_Sources = unique(Combined.run_id, 'stable');
    Combined_Entry.Class_Names = cellstr(classNames(:));
    Combined_Entry.Class_Label_Map = Class_Label_Map;
    Combined_Entry.Per_Message = Records;
    Combined_External_Test_Results.(Group_Fields{A}) = Combined_Entry;
    Combined_Summaries{end+1,1} = summaryTable( ...
        Group, join(Dataset_Sources, "+"), Group, Summary);
    fprintf('Aggregato %s: %s, %d messaggi.\n', Group, join(Dataset_Sources, " + "), height(Combined))
end
save(fullfile(Output_Folder, 'Combined_External_Test_Results.mat'), ...
    'Combined_External_Test_Results', 'Class_Label_Map', '-v7');
if ~isempty(Combined_Summaries)
    Combined_Summary = vertcat(Combined_Summaries{:});
    writetable(Combined_Summary, fullfile(Output_Folder, ...
        'Combined_External_Test_summary.csv'), 'Encoding', 'UTF-8');
end

%% Funzioni di supporto
function Labels = normalizeLabels(Values, classNames)
    % Accetta sia nomi delle classi sia indici numerici salvati come testo.
    Labels = strip(string(Values(:)));
    Numbers = str2double(Labels);
    Numeric = isfinite(Numbers) & Numbers == fix(Numbers) & ...
        Numbers >= 1 & Numbers <= numel(classNames);
    Labels(Numeric) = reshape(classNames(Numbers(Numeric)), [], 1);
    if any(~ismember(Labels, classNames))
        error('Etichette non presenti in classNames: %s.', join(unique(Labels(~ismember(Labels, classNames))), ", "))
    end
end

function Summary = summarizeExperiment(Records, classNames, Target_Classes)
    % Le metriche aggiunte usano esplicitamente le 19 classi target.
    [~, True_Index] = ismember(string(Records.true_label), classNames);
    [~, Pred_Index] = ismember(string(Records.pred_label), classNames);
    Counts = accumarray([True_Index(:), Pred_Index(:)], 1, ...
        [numel(classNames), numel(classNames)]);
    TP = diag(Counts);
    Support = sum(Counts,2);
    Predicted = sum(Counts,1)';
    FP = Predicted - TP;
    FN = Support - TP;
    N = sum(Counts(:));
    TN = N - TP - FP - FN;
    Precision = TP ./ max(Predicted,1);
    Recall = TP ./ max(Support,1);
    F1 = 2 * TP ./ max(Support + Predicted,1);
    Specificity = TN ./ max(TN + FP,1);
    Summary = struct();
    Summary.Sample_Count = N;
    Summary.Correct_Count = sum(TP);
    Summary.Accuracy = sum(TP) / N;
    Summary.Macro_Precision_19 = mean(Precision(Target_Classes));
    Summary.Macro_Recall_19 = mean(Recall(Target_Classes));
    Summary.Macro_F1_19 = mean(F1(Target_Classes));
    Summary.Macro_Specificity_19 = mean(Specificity(Target_Classes));
    Summary.Weighted_F1 = sum(F1 .* Support) / N;
    Summary.Confusion_Matrix = Counts;
    Summary.Per_Class = table(cellstr(classNames(:)), Target_Classes(:), ...
        Support, Predicted, TP, FP, FN, TN, Precision, Recall, F1, Specificity, ...
        'VariableNames', {'Class', 'Is_Target', 'Support', 'Predicted', ...
        'TP', 'FP', 'FN', 'TN', 'Precision', 'Recall', 'F1', 'Specificity'});
    Summary.Total_Latency_s = sum(Records.latency_s);
    Summary.Mean_Latency_s = mean(Records.latency_s);
    Summary.Median_Latency_s = median(Records.latency_s);
    Summary.Std_Latency_s = std(Records.latency_s);
    Summary.P95_Latency_s = prctile(Records.latency_s,95);
    Summary.Max_Latency_s = max(Records.latency_s);
    Fields = fieldnames(Records);
    for K = 1:numel(Fields)
        if endsWith(Fields{K}, '_Tokens')
            % sum propaga NaN: un totale incompleto non viene presentato come completo.
            Summary.(Fields{K}) = sum(Records.(Fields{K}));
        end
    end
    Summary.Classifier_Cache_Read_Fraction = NaN;
    Summary.Classifier_Cache_Write_Fraction = NaN;
    if Summary.Input_Tokens > 0
        Summary.Classifier_Cache_Read_Fraction = Summary.Input_Cached_Tokens / Summary.Input_Tokens;
        Summary.Classifier_Cache_Write_Fraction = Summary.Input_Cache_Write_Tokens / Summary.Input_Tokens;
    end
    With_Tokens = Records.classifier_has_tokens == 1;
    Without_Tokens = Records.classifier_has_tokens == 0;
    Summary.Classifier_Messages_With_Tokens = sum(With_Tokens);
    Summary.Classifier_Messages_Without_Tokens = sum(Without_Tokens);
    Summary.Classifier_Messages_Unknown_Usage = sum(isnan(Records.classifier_has_tokens));
    Summary.Without_Classifier_Tokens_Fraction = sum(Without_Tokens) / N;
    Summary.Accuracy_With_Classifier_Tokens = mean(Records.is_correct(With_Tokens));
    Summary.Accuracy_Without_Classifier_Tokens = mean(Records.is_correct(Without_Tokens));
    % Precisione per classe nel sottoinsieme senza token del classificatore.
    Sub_Counts = zeros(numel(classNames));
    if any(Without_Tokens)
        Sub_Counts = accumarray([True_Index(Without_Tokens), Pred_Index(Without_Tokens)], ...
            1, [numel(classNames), numel(classNames)]);
    end
    Sub_Predicted = sum(Sub_Counts,1)';
    Sub_TP = diag(Sub_Counts);
    Sub_Precision = Sub_TP ./ Sub_Predicted;
    Summary.Without_Classifier_Tokens_Per_Class = table( ...
        cellstr(classNames(:)), Sub_Predicted, Sub_TP, Sub_Precision, ...
        'VariableNames', {'Class', 'Predicted', 'Correct', 'Precision'});
    % Questi conteggi non ricostruiscono il numero esatto delle chiamate API.
end

function T = summaryTable(Run, Dataset, Group, Summary)
    % CSV con una riga per esperimento; i dettagli per classe restano nel MAT.
    Row = struct();
    Row.Run = {char(Run)};
    Row.Dataset = {char(Dataset)};
    Row.Group = {char(Group)};
    Fields = fieldnames(Summary);
    for K = 1:numel(Fields)
        Value = Summary.(Fields{K});
        if (isnumeric(Value) || islogical(Value)) && isscalar(Value)
            Row.(Fields{K}) = Value;
        end
    end
    T = struct2table(Row);
end

function Combined = concatenateTables(Parts)
    % Alcuni run possono avere campi EMS aggiuntivi o non salvarli affatto.
    Fields = {};
    for C = 1:numel(Parts)
        Fields = union(Fields, Parts{C}.Properties.VariableNames, 'stable');
    end
    for C = 1:numel(Parts)
        Missing = setdiff(Fields, Parts{C}.Properties.VariableNames, 'stable');
        for K = 1:numel(Missing)
            Parts{C}.(Missing{K}) = nan(height(Parts{C}),1);
        end
        Parts{C} = Parts{C}(:,Fields);
    end
    Combined = vertcat(Parts{:});
end
