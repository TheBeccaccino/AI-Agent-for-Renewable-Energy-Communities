function [Single_Stage_LLM_ON, Local_Classifier_ON, LLM_based_Classifier_ON] = Classificator_Set_Up(Classificator)
%% Classificator supported: Local, LLM, Hybrid, Single, H-Single

% SINGLE-STAGE baseline:
% Single_Stage_LLM_ON = 1, one LLM call performs the complete intent-routing tree.
% Local_Classifier_ON = 1, Local Calssifier active
% LLM_based_Classifier_ON = 1, LLM Classifier active

switch Classificator
    case "Local"
        Single_Stage_LLM_ON = 0;
        Local_Classifier_ON = 1;
        LLM_based_Classifier_ON = 0;

    case "LLM"
        Single_Stage_LLM_ON = 0;
        Local_Classifier_ON = 0;
        LLM_based_Classifier_ON = 1;

    case "Hybrid"
        Single_Stage_LLM_ON = 0;
        Local_Classifier_ON = 1;
        LLM_based_Classifier_ON = 1;

    case "Single"
        Single_Stage_LLM_ON = 1;
        Local_Classifier_ON = 0;
        LLM_based_Classifier_ON = 0;

    case "H-Single"
        Single_Stage_LLM_ON = 1;
        Local_Classifier_ON = 1;
        LLM_based_Classifier_ON = 0;

end