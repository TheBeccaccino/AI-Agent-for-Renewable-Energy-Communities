function label = local_Admin_EMS_Classify(msg)
%LOCAL_ADMIN_EMS_CLASSIFY Conservative local classifier for ADMIN EMS commands.
%
% Design goal:
%   precision > coverage.
% A local label is emitted only when exactly one high-confidence intent is
% detected. Ambiguous/conflicting messages return "UNRESOLVED".
%
% Returns one of:
%   BESS_COORD_ON, BESS_COORD_OFF,
%   LOAD_COORD_ON, LOAD_COORD_OFF,
%   ADVICE_COORD_ON, ADVICE_COORD_OFF,
%   UNRESOLVED

%% MAIN
    s = normalizeMessage(msg);

    if strlength(s) == 0
        label = "UNRESOLVED";
        return
    end

    matches = [ ...
        isBESSCoordOnIntent(s), ...
        isBESSCoordOffIntent(s), ...
        isLoadCoordOnIntent(s), ...
        isLoadCoordOffIntent(s), ...
        isAdviceCoordOnIntent(s), ...
        isAdviceCoordOffIntent(s)];

    labels = [ ...
        "BESS_COORD_ON", ...
        "BESS_COORD_OFF", ...
        "LOAD_COORD_ON", ...
        "LOAD_COORD_OFF", ...
        "ADVICE_COORD_ON", ...
        "ADVICE_COORD_OFF"];

    idx = find(matches);

    if numel(idx) == 1
        label = labels(idx);
    else
        label = "UNRESOLVED";
    end
end


%% BESS COORDINATION ON
function tf = isBESSCoordOnIntent(s)
    explicitPatterns = [
        "attiva coordinamento bess"
        "abilita coordinamento bess"
        "riattiva coordinamento bess"
        "avvia coordinamento bess"
        "attiva il coordinamento bess"
        "abilita il coordinamento bess"
        "attiva coordinamento storage"
        "abilita coordinamento storage"
        "riattiva coordinamento storage"
        "attiva coordinamento batterie"
        "abilita coordinamento batterie"
        "riattiva coordinamento batterie"
        "attiva coordinamento accumuli"
        "abilita coordinamento accumuli"
        "attiva gestione coordinata delle batterie"
        "attiva gestione automatica delle batterie"
        "attiva gestione automatica degli storage"
        "coordina automaticamente le batterie"
        "coordina automaticamente gli storage"
        "coordinamento bess on"
        "coordinamento storage on"
        "enable bess coordination"
        "enable storage coordination"
        "turn on bess coordination"
    ];

    if hasOffCue(s) || containsAny(s, [
            "non attivare"
            "non abilitare"
            "non coordinare"
        ])
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (hasBESSTarget(s) && hasCoordinationConcept(s) && hasOnCue(s));
end


%% BESS COORDINATION OFF
function tf = isBESSCoordOffIntent(s)
    explicitPatterns = [
        "disattiva coordinamento bess"
        "disabilita coordinamento bess"
        "ferma coordinamento bess"
        "sospendi coordinamento bess"
        "spegni coordinamento bess"
        "disattiva il coordinamento bess"
        "disabilita il coordinamento bess"
        "disattiva coordinamento storage"
        "disabilita coordinamento storage"
        "ferma coordinamento storage"
        "disattiva coordinamento batterie"
        "disabilita coordinamento batterie"
        "ferma coordinamento batterie"
        "disattiva coordinamento accumuli"
        "disabilita coordinamento accumuli"
        "disattiva gestione coordinata delle batterie"
        "disattiva gestione automatica delle batterie"
        "disattiva gestione automatica degli storage"
        "non coordinare le batterie"
        "non coordinare piu le batterie"
        "non coordinare gli storage"
        "non coordinare piu gli storage"
        "non attivare il coordinamento bess"
        "coordinamento bess off"
        "coordinamento storage off"
        "disable bess coordination"
        "disable storage coordination"
        "turn off bess coordination"
    ];

    if hasNegatedOffAction(s)
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (hasBESSTarget(s) && hasCoordinationConcept(s) && hasOffCue(s));
end


%% LOAD COORDINATION ON
function tf = isLoadCoordOnIntent(s)
    explicitPatterns = [
        "attiva coordinamento carichi"
        "abilita coordinamento carichi"
        "riattiva coordinamento carichi"
        "avvia coordinamento carichi"
        "attiva il coordinamento dei carichi"
        "abilita il coordinamento dei carichi"
        "attiva coordinamento dei carichi controllabili"
        "abilita coordinamento dei carichi controllabili"
        "attiva gestione coordinata dei carichi"
        "attiva gestione automatica dei carichi"
        "coordina automaticamente i carichi"
        "coordina automaticamente i carichi controllabili"
        "coordinamento carichi on"
        "load coordination on"
        "load coord on"
        "enable load coordination"
        "turn on load coordination"
    ];

    if hasOffCue(s) || containsAny(s, [
            "non attivare"
            "non abilitare"
            "non coordinare"
        ])
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (hasLoadTarget(s) && hasCoordinationConcept(s) && hasOnCue(s));
end


%% LOAD COORDINATION OFF
function tf = isLoadCoordOffIntent(s)
    explicitPatterns = [
        "disattiva coordinamento carichi"
        "disabilita coordinamento carichi"
        "ferma coordinamento carichi"
        "sospendi coordinamento carichi"
        "spegni coordinamento carichi"
        "disattiva il coordinamento dei carichi"
        "disabilita il coordinamento dei carichi"
        "disattiva coordinamento dei carichi controllabili"
        "disabilita coordinamento dei carichi controllabili"
        "disattiva gestione coordinata dei carichi"
        "ferma la gestione automatica dei carichi"
        "disattiva gestione automatica carichi"
        "non coordinare i carichi"
        "non coordinare piu i carichi"
        "non attivare il coordinamento dei carichi"
        "coordinamento carichi off"
        "load coordination off"
        "load coord off"
        "disable load coordination"
        "turn off load coordination"
    ];

    if hasNegatedOffAction(s)
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (hasLoadTarget(s) && hasCoordinationConcept(s) && hasOffCue(s));
end


%% ADVICE COORDINATION ON
function tf = isAdviceCoordOnIntent(s)
    explicitPatterns = [
        "attiva i consigli agli utenti"
        "abilita i consigli agli utenti"
        "riattiva i consigli agli utenti"
        "avvia i consigli agli utenti"
        "attiva consigli per gli utenti"
        "abilita consigli per gli utenti"
        "attiva suggerimenti per i membri"
        "abilita suggerimenti per i membri"
        "attiva raccomandazioni per gli utenti"
        "attiva invio automatico consigli"
        "abilita invio automatico consigli"
        "manda automaticamente consigli agli utenti"
        "invia automaticamente consigli agli utenti"
        "attiva raccomandazioni energetiche agli utenti"
        "attiva advisory comunitario"
        "abilita advisory comunitario"
        "advice coordination on"
        "advice coord on"
        "enable community advice"
    ];

    if hasOffCue(s) || containsAny(s, [
            "non attivare"
            "non abilitare"
            "non inviare"
            "non mandare"
        ])
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (hasAdviceTarget(s) && hasCommunityRecipient(s) && hasOnCue(s));
end


%% ADVICE COORDINATION OFF
function tf = isAdviceCoordOffIntent(s)
    explicitPatterns = [
        "disattiva i consigli agli utenti"
        "disabilita i consigli agli utenti"
        "ferma i consigli agli utenti"
        "sospendi i consigli agli utenti"
        "interrompi i consigli agli utenti"
        "disattiva consigli per gli utenti"
        "disabilita consigli per gli utenti"
        "disattiva suggerimenti per i membri"
        "disattiva raccomandazioni per gli utenti"
        "disattiva invio automatico consigli"
        "disabilita invio automatico consigli"
        "non inviare consigli agli utenti"
        "non inviare piu consigli agli utenti"
        "non mandare consigli ai membri"
        "smetti di mandare consigli ai membri"
        "disattiva raccomandazioni energetiche agli utenti"
        "disattiva advisory comunitario"
        "non attivare i consigli agli utenti"
        "advice coordination off"
        "advice coord off"
        "disable community advice"
    ];

    if hasNegatedOffAction(s)
        tf = false;
        return
    end

    tf = containsAny(s, explicitPatterns) || ...
         (hasAdviceTarget(s) && hasCommunityRecipient(s) && hasOffCue(s));
end


%% Semantic components
function tf = hasBESSTarget(s)
    terms = [
        "bess"
        "storage"
        "batteria"
        "batterie"
        "accumulo"
        "accumuli"
        "sistemi di accumulo"
        "battery"
        "batteries"
    ];
    tf = containsAny(s, terms);
end


function tf = hasLoadTarget(s)
    terms = [
        "carico"
        "carichi"
        "carichi controllabili"
        "carichi flessibili"
        "utenze flessibili"
        "elettrodomestici"
        "load"
        "loads"
        "controllable loads"
        "flexible loads"
    ];
    tf = containsAny(s, terms);
end


function tf = hasAdviceTarget(s)
    terms = [
        "consigli"
        "suggerimenti"
        "raccomandazioni"
        "advisory"
        "advice"
        "recommendations"
    ];
    tf = containsAny(s, terms);
end


function tf = hasCommunityRecipient(s)
    terms = [
        "utenti"
        "membri"
        "partecipanti"
        "comunita"
        "prosumer"
        "prosumers"
        "users"
        "members"
        "community"
    ];
    tf = containsAny(s, terms);
end


function tf = hasCoordinationConcept(s)
    terms = [
        "coordinamento"
        "coordina"
        "coordinata"
        "coordinato"
        "gestione coordinata"
        "gestione automatica"
        "controllo coordinato"
        "coordination"
        "coordinate"
        "coordinated"
        "coord "
    ];
    tf = containsAny(s, terms);
end


function tf = hasOnCue(s)
    terms = [
        "attiva"
        "abilita"
        "riattiva"
        "avvia"
        "accendi"
        "coordina automaticamente"
        "enable"
        "activate"
        "turn on"
        " on"
    ];
    tf = containsAny(s, terms);
end


function tf = hasOffCue(s)
    terms = [
        "disattiva"
        "disabilita"
        "ferma"
        "sospendi"
        "spegni"
        "interrompi"
        "blocca"
        "non coordinare"
        "non inviare"
        "non mandare"
        "non attivare"
        "non abilitare"
        "smetti"
        "disable"
        "deactivate"
        "turn off"
        " stop"
        " off"
    ];
    tf = containsAny(s, terms);
end


function tf = hasNegatedOffAction(s)
    patterns = [
        "non disattivare"
        "non disabilitare"
        "non fermare"
        "non sospendere"
        "non spegnere"
        "non interrompere"
        "non bloccare"
        "do not disable"
        "dont disable"
        "do not turn off"
    ];
    tf = containsAny(s, patterns);
end


%% Utility
function tf = containsAny(s, patterns)
    tf = any(contains(s, lower(string(patterns))));
end
