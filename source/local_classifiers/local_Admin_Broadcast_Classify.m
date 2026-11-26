function label = local_Admin_Broadcast_Classify(msg)
%LOCAL_ADMIN_BROADCAST_CLASSIFY Conservative local classifier for the
% ADMIN broadcast workflow.
%
% Design goal:
%   precision > coverage.
%
% Returns one of:
%   MSG_ABORT, MSG_READY, MSG_NOT_READY, UNRESOLVED

%% MAIN
    s = normalizeMessage(msg);

    if strlength(s) == 0
        label = "UNRESOLVED";
        return
    end

    % Abort is intentionally evaluated first because it is a safety/control
    % command for the ongoing broadcast flow.
    if isAbortIntent(s)
        label = "MSG_ABORT";
        return
    end

    readyMatch    = isReadyBroadcastIntent(s);
    notReadyMatch = isNotReadyBroadcastIntent(s);

    % Accept only an unambiguous READY / NOT_READY decision.
    if readyMatch && ~notReadyMatch
        label = "MSG_READY";
    elseif notReadyMatch && ~readyMatch
        label = "MSG_NOT_READY";
    else
        label = "UNRESOLVED";
    end
end


%% MSG_ABORT
function tf = isAbortIntent(s)
    patterns = [
        "annulla il broadcast"
        "annulla broadcast"
        "annulla il messaggio"
        "cancella il broadcast"
        "ferma il broadcast"
        "interrompi il broadcast"
        "non inviare il messaggio"
        "non mandare il messaggio"
        "lascia perdere il broadcast"
        "lascia perdere il messaggio"
        "stop broadcast"
        "abort broadcast"
    ];
    tf = containsAny(s, patterns);
end


%% MSG_NOT_READY
function tf = isNotReadyBroadcastIntent(s)
    patterns = [
        "voglio mandare un messaggio"
        "vorrei mandare un messaggio"
        "devo mandare un messaggio"
        "ho bisogno di mandare un messaggio"
        "ho bisogno di inviare un messaggio"
        "voglio inviare un messaggio"
        "vorrei inviare un messaggio"
        "devo inviare un messaggio"
        "voglio contattare i membri"
        "devo contattare i membri"
        "voglio avvisare i membri"
        "devo avvisare la comunita"
        "prepara un broadcast"
        "aiutami a scrivere una comunicazione"
        "voglio preparare una comunicazione"
        "vorrei preparare una comunicazione"
        "i want to send a message"
        "help me prepare a broadcast"
    ];

    % If actual broadcast content is already supplied, it is not NOT_READY.
    tf = containsAny(s, patterns) && ~hasExplicitBroadcastContent(s);
end


%% MSG_READY
function tf = isReadyBroadcastIntent(s)
    explicitPatterns = [
        "avvisa tutti che"
        "avvisa i membri che"
        "comunica a tutti che"
        "comunica ai membri che"
        "notifica agli utenti che"
        "manda ai membri che"
        "invia ai membri che"
        "messaggio:"
        "message:"
    ];

    tf = containsAny(s, explicitPatterns) || hasExplicitBroadcastContent(s);
end


function tf = hasExplicitBroadcastContent(s)
    % Conservative rule: a recipient plus a generic preposition such as
    % "di" is NOT sufficient evidence that the actual broadcast text has
    % already been supplied. Require "che", "that", ":" or quotes.
    sendActions = [
        "avvisa"
        "comunica"
        "notifica"
        "informa"
        "manda"
        "invia"
        "scrivi"
        "tell"
        "notify"
        "inform"
        "send"
    ];

    recipients = [
        "membri"
        "utenti"
        "comunita"
        "partecipanti"
        "tutti"
        "members"
        "users"
        "community"
        "everyone"
    ];

    contentConnectors = [
        " che "
        ":"
        """"
        " that "
    ];

    genericIntentPatterns = [
        "bisogno di inviare"
        "bisogno di mandare"
        "voglio inviare"
        "voglio mandare"
        "devo inviare"
        "devo mandare"
        "vorrei inviare"
        "vorrei mandare"
        "i want to send"
        "i need to send"
    ];

    hasAction    = containsAny(s, sendActions);
    hasRecipient = containsAny(s, recipients);
    hasContent   = containsAny(s, contentConnectors);
    genericOnly  = containsAny(s, genericIntentPatterns);

    tf = hasAction && hasRecipient && hasContent && ~genericOnly;
end


%% Utility
function tf = containsAny(s, patterns)
    tf = any(contains(s, lower(string(patterns))));
end
