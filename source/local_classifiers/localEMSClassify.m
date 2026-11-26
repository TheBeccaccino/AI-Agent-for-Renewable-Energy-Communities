function label = localEMSClassify(msg)
%LOCALEMSCLASSIFY Conservative local EMS intent classifier.
%
% Design goal:
%   precision > coverage.
% A message is classified locally only when exactly one high-confidence
% intent is detected. Ambiguous/conflicting cases return "UNRESOLVED" and
% are delegated to the LLM classifier.
%
% Returns one of:
%   ADVICE_ON, ADVICE_OFF, LOAD_PLANNING,
%   AUTO_PLANNING_ON, AUTO_PLANNING_OFF, UNRESOLVED

%% MAIN
    s = normalizeMessage(msg);

    if strlength(s) == 0
        label = "UNRESOLVED";
        return
    end

    % Evaluate independently and accept only a unique match.
    matches = [ ...
        isAdviceOnIntent(s), ...
        isAdviceOffIntent(s), ...
        isLoadPlanningIntent(s), ...
        isAutoPlanningOnIntent(s), ...
        isAutoPlanningOffIntent(s)];

    labels = [ ...
        "ADVICE_ON", ...
        "ADVICE_OFF", ...
        "LOAD_PLANNING", ...
        "AUTO_PLANNING_ON", ...
        "AUTO_PLANNING_OFF"];

    idx = find(matches);

    if numel(idx) == 1
        label = labels(idx);
    else
        % Zero matches OR conflicting matches -> LLM fallback.
        label = "UNRESOLVED";
    end
end


%% ADVICE ON
function tf = isAdviceOnIntent(s)
    explicitPatterns = [
        "attiva consigli"
        "abilita consigli"
        "riattiva consigli"
        "attiva i consigli"
        "abilita i consigli"
        "attiva i consigli automatici"
        "abilita i consigli automatici"
        "attiva suggerimenti"
        "abilita suggerimenti"
        "attiva raccomandazioni"
        "abilita raccomandazioni"
        "attiva notifiche energetiche"
        "voglio ricevere consigli"
        "voglio ricevere suggerimenti"
        "mandami consigli"
        "inviami consigli"
        "consigliami automaticamente"
        "abilita l advisory"
        "attiva l advisory"
        "enable advice"
        "enable recommendations"
        "turn on advice"
    ];

    adviceTerms = [
        "consigli"
        "suggerimenti"
        "raccomandazioni"
        "advisory"
        "notifiche energetiche"
        "advice"
        "recommendations"
    ];

    activationTerms = [
        "attiva"
        "abilita"
        "riattiva"
        "accendi"
        "enable"
        "activate"
        "turn on"
    ];

    % Strong veto: do not let strings such as "disattiva" or negated
    % requests leak into the ON class.
    if hasAdviceOffCue(s) || containsAny(s, [
            "non attivare"
            "non abilitare"
            "non voglio ricevere"
            "non mandarmi"
            "non inviarmi"
        ])
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (containsAny(s, adviceTerms) && containsAny(s, activationTerms));
end


%% ADVICE OFF
function tf = isAdviceOffIntent(s)
    explicitPatterns = [
        "disattiva consigli"
        "disabilita consigli"
        "ferma i consigli"
        "interrompi i consigli"
        "spegni i consigli"
        "smetti di consigliarmi"
        "non mandarmi consigli"
        "non inviarmi consigli"
        "non voglio consigli"
        "non voglio piu consigli"
        "non voglio ricevere consigli"
        "non voglio piu ricevere consigli"
        "disattiva suggerimenti"
        "disabilita suggerimenti"
        "disattiva raccomandazioni"
        "disabilita raccomandazioni"
        "disattiva notifiche energetiche"
        "disattiva l advisory"
        "non attivare i consigli"
        "disable advice"
        "disable recommendations"
        "turn off advice"
    ];

    adviceTerms = [
        "consigli"
        "suggerimenti"
        "raccomandazioni"
        "advisory"
        "notifiche energetiche"
        "advice"
        "recommendations"
    ];

    % "non disattivare ..." means the opposite of an OFF request.
    if containsAny(s, [
            "non disattivare"
            "non disabilitare"
            "non spegnere"
            "non interrompere"
            "non fermare"
            "do not disable"
            "dont disable"
        ])
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (containsAny(s, adviceTerms) && hasAdviceOffCue(s));
end


function tf = hasAdviceOffCue(s)
    offTerms = [
        "disattiva"
        "disabilita"
        "spegni"
        "ferma"
        "interrompi"
        "sospendi"
        "smetti"
        "non voglio"
        "non mandarmi"
        "non inviarmi"
        "non attivare"
        "disable"
        "deactivate"
        "turn off"
        "stop"
    ];

    tf = containsAny(s, offTerms);
end


%% AUTO PLANNING ON
function tf = isAutoPlanningOnIntent(s)
    explicitPatterns = [
        "attiva pianificazione automatica"
        "abilita pianificazione automatica"
        "riattiva pianificazione automatica"
        "avvia pianificazione automatica"
        "attiva la pianificazione automatica"
        "abilita la pianificazione automatica"
        "attiva auto planning"
        "abilita auto planning"
        "auto planning on"
        "pianifica automaticamente i carichi"
        "programma automaticamente i carichi"
        "gestisci automaticamente i carichi"
        "automatizza la pianificazione dei carichi"
        "automatizza la gestione dei carichi"
        "lascia che l ems pianifichi automaticamente i carichi"
        "lascia che l ems gestisca automaticamente i carichi"
        "enable automatic planning"
        "enable automatic scheduling"
        "automatic planning on"
        "turn on automatic planning"
    ];

    activationTerms = [
        "attiva"
        "abilita"
        "riattiva"
        "avvia"
        "accendi"
        "automatizza"
        "enable"
        "activate"
        "turn on"
    ];

    % A genuine AUTO_PLANNING_ON request must contain a clear automatic
    % planning concept, not merely a generic word such as "automatico".
    automaticPlanningTerms = [
        "pianificazione automatica"
        "programmazione automatica"
        "scheduling automatico"
        "auto planning"
        "automatic planning"
        "automatic scheduling"
        "automaticamente i carichi"
        "automaticamente gli elettrodomestici"
        "gestione automatica dei carichi"
        "gestione automatica carichi"
    ];

    if hasAutoPlanningOffCue(s) || containsAny(s, [
            "non attivare"
            "non abilitare"
            "non avviare"
            "non automatizzare"
            "manuale"
            "manualmente"
        ])
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (containsAny(s, activationTerms) && ...
          containsAny(s, automaticPlanningTerms));
end


%% AUTO PLANNING OFF
function tf = isAutoPlanningOffIntent(s)
    explicitPatterns = [
        "disattiva pianificazione automatica"
        "disabilita pianificazione automatica"
        "ferma pianificazione automatica"
        "sospendi pianificazione automatica"
        "spegni pianificazione automatica"
        "disattiva la pianificazione automatica"
        "disabilita la pianificazione automatica"
        "disattiva auto planning"
        "disabilita auto planning"
        "spegni l auto planning"
        "ferma l auto planning"
        "auto planning off"
        "non pianificare automaticamente i carichi"
        "non programmare automaticamente i carichi"
        "non gestire automaticamente i carichi"
        "non attivare la pianificazione automatica"
        "voglio scegliere manualmente gli orari"
        "voglio gestire manualmente i carichi"
        "torna alla gestione manuale"
        "passa alla gestione manuale"
        "disable automatic planning"
        "automatic planning off"
        "turn off automatic planning"
    ];

    automaticPlanningTerms = [
        "pianificazione automatica"
        "programmazione automatica"
        "scheduling automatico"
        "auto planning"
        "automatic planning"
        "automatic scheduling"
        "automaticamente i carichi"
        "automaticamente gli elettrodomestici"
        "gestione automatica dei carichi"
        "gestione automatica carichi"
    ];

    manualModeTerms = [
        "gestione manuale"
        "modalita manuale"
        "manualmente i carichi"
        "scegliere manualmente gli orari"
        "decidere manualmente gli orari"
        "scelgo io gli orari"
        "decido io gli orari"
    ];

    % Avoid interpreting "non disattivare ..." as OFF.
    if containsAny(s, [
            "non disattivare"
            "non disabilitare"
            "non spegnere"
            "non fermare"
            "non sospendere"
            "do not disable"
            "dont disable"
        ])
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (containsAny(s, automaticPlanningTerms) && hasAutoPlanningOffCue(s)) || ...
         containsAny(s, manualModeTerms);
end


function tf = hasAutoPlanningOffCue(s)
    offTerms = [
        "disattiva"
        "disabilita"
        "spegni"
        "ferma"
        "sospendi"
        "interrompi"
        "blocca"
        "annulla"
        "non pianificare"
        "non programmare"
        "non gestire"
        "non attivare"
        "non abilitare"
        "disable"
        "deactivate"
        "turn off"
        "stop"
    ];

    tf = containsAny(s, offTerms);
end


%% LOAD PLANNING
function tf = isLoadPlanningIntent(s)
% Concrete one-shot planning/scheduling requests only.
% Requests about enabling/disabling the persistent automatic mode are
% deliberately excluded and delegated to AUTO_PLANNING_ON/OFF or the LLM.

    automaticModeTerms = [
        "pianificazione automatica"
        "programmazione automatica"
        "scheduling automatico"
        "auto planning"
        "automatic planning"
        "automatic scheduling"
        "gestione automatica dei carichi"
        "gestione automatica carichi"
        "automatizza"
        "automaticamente"
        "automatico"
        "automatica"
        "automatici"
        "automatiche"
        "in automatico"
        "autonomamente"
        "automaticamente i carichi"
        "automaticamente gli elettrodomestici"
    ];

    negativePlanningTerms = [
        "non pianificare"
        "non programmare"
        "non schedulare"
        "non spostare"
        "annulla la pianificazione"
        "cancella la pianificazione"
    ];

    if containsAny(s, automaticModeTerms) || ...
       containsAny(s, negativePlanningTerms)
        tf = false;
        return
    end

    directPatterns = [
        "pianifica i carichi"
        "pianifica la lavatrice"
        "pianifica la lavastoviglie"
        "pianifica l asciugatrice"
        "pianifica la ricarica"
        "programma i carichi"
        "programma la lavatrice"
        "programma la lavastoviglie"
        "schedula i carichi"
        "schedula la lavatrice"
        "organizza i carichi"
        "crea un piano per i carichi"
        "prepara un piano per i carichi"
        "aiutami a pianificare i carichi"
        "quando conviene usare la lavatrice"
        "quando conviene usare la lavastoviglie"
        "quando conviene avviare"
        "quando dovrei avviare"
        "qual e l orario migliore per usare"
        "schedule the washing machine"
        "schedule the dishwasher"
        "plan my loads"
    ];

    loadTerms = [
        "carico"
        "carichi"
        "lavatrice"
        "lavastoviglie"
        "asciugatrice"
        "boiler"
        "pompa di calore"
        "climatizzatore"
        "condizionatore"
        "forno"
        "ricarica auto"
        "auto elettrica"
        "elettrodomestici"
        "dispositivi flessibili"
        "load"
        "loads"
        "washing machine"
        "dishwasher"
        "ev charging"
    ];

    planningActions = [
        "pianifica"
        "programma"
        "schedula"
        "organizza"
        "distribuisci"
        "ottimizza gli orari"
        "sposta i consumi"
        "definisci gli orari"
        "proponi un orario"
        "prepara un piano"
        "crea un piano"
        "schedule"
        "plan"
    ];

    operationalQuestions = [
        "quando conviene"
        "quando devo"
        "quando dovrei"
        "a che ora"
        "in quale fascia"
        "meglio oggi o domani"
        "meglio stasera o domani"
        "quando posso avviare"
        "quando far partire"
        "come distribuisco"
        "come organizzo"
        "in che ordine"
        "what time should"
        "when should"
    ];

    genericExplanationPatterns = [
        "come funziona la pianificazione"
        "cos e la pianificazione"
        "cosa significa pianificazione"
        "perche conviene pianificare"
        "come viene scelto l orario"
        "spiegami la pianificazione"
        "how does load planning work"
    ];

    if containsAny(s, genericExplanationPatterns)
        tf = false;
        return
    end

    tf = containsAny(s, directPatterns) || ...
         (containsAny(s, loadTerms) && ...
          (containsAny(s, planningActions) || ...
           containsAny(s, operationalQuestions)));
end


%% Utility
function tf = containsAny(s, patterns)
    tf = any(contains(s, lower(string(patterns))));
end
