function [Class_entry, Valid_Route] = CerBot_Map_SingleStage_Route(Route_label, Class_list_Template)
%CERBOT_MAP_SINGLESTAGE_ROUTE
% Converts the single-stage LLM route label into the same hierarchical
% Class_list structure already used by CERBot.
%
% The data structure is NOT changed:
%   Class_entry.MAIN
%   Class_entry.EMS
%   Class_entry.ADMIN
%   Class_entry.ADMIN_EMS
%   Class_entry.ADMIN_BRD

    % Always clear the previous routing path to avoid stale subclasses
    Class_entry = Class_list_Template;
    Valid_Route = true;

    route = upper(strip(string(Route_label)));

    % Defensive cleanup in case the model adds code fences/backticks
    route = erase(route, "`");
    route = erase(route, "*");
    route = strip(route);

    switch route

        % =============================================================
        % STANDARD USER - GENERIC
        % =============================================================
        case "USER_START"
            Class_entry.MAIN = "START";

        case "USER_RESET"
            Class_entry.MAIN = "RESET";

        case "USER_QUESTION"
            Class_entry.MAIN = "QUESTION";

        case "USER_CHANGE"
            Class_entry.MAIN = "CHANGE";

        case "USER_SIMULATION"
            Class_entry.MAIN = "SIMULATION";

        case "USER_INSULT"
            Class_entry.MAIN = "INSULT";

        case "USER_CLASSLESS"
            Class_entry.MAIN = "CLASSLESS";

        % =============================================================
        % STANDARD USER - EMS
        % =============================================================
        case "USER_EMS_ADVICE_ON"
            Class_entry.MAIN = "EMS";
            Class_entry.EMS  = "ADVICE_ON";

        case "USER_EMS_ADVICE_OFF"
            Class_entry.MAIN = "EMS";
            Class_entry.EMS  = "ADVICE_OFF";

        case "USER_EMS_LOAD_PLANNING"
            Class_entry.MAIN = "EMS";
            Class_entry.EMS  = "LOAD_PLANNING";

        case "USER_EMS_AUTO_PLANNING_ON"
            Class_entry.MAIN = "EMS";
            Class_entry.EMS  = "AUTO_PLANNING_ON";

        case "USER_EMS_AUTO_PLANNING_OFF"
            Class_entry.MAIN = "EMS";
            Class_entry.EMS  = "AUTO_PLANNING_OFF";

        case "USER_EMS_OTHER"
            Class_entry.MAIN = "EMS";
            Class_entry.EMS  = "EMS_OTHER";

        % =============================================================
        % ADMIN - GENERIC
        % =============================================================
        case "ADMIN_START"
            Class_entry.MAIN  = "ADMIN";
            Class_entry.ADMIN = "START";

        case "ADMIN_RESET"
            Class_entry.MAIN  = "ADMIN";
            Class_entry.ADMIN = "RESET";

        case "ADMIN_QUESTION"
            Class_entry.MAIN  = "ADMIN";
            Class_entry.ADMIN = "QUESTION";

        case "ADMIN_CHANGE"
            Class_entry.MAIN  = "ADMIN";
            Class_entry.ADMIN = "CHANGE";

        case "ADMIN_SIMULATION"
            Class_entry.MAIN  = "ADMIN";
            Class_entry.ADMIN = "SIMULATION";

        case "ADMIN_INSULT"
            Class_entry.MAIN  = "ADMIN";
            Class_entry.ADMIN = "INSULT";

        case "ADMIN_CLASSLESS"
            Class_entry.MAIN  = "ADMIN";
            Class_entry.ADMIN = "CLASSLESS";

        % =============================================================
        % ADMIN - EMS
        % =============================================================
        case "ADMIN_EMS_ADVICE_COORD_ON"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "EMS";
            Class_entry.ADMIN_EMS = "ADVICE_COORD_ON";

        case "ADMIN_EMS_ADVICE_COORD_OFF"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "EMS";
            Class_entry.ADMIN_EMS = "ADVICE_COORD_OFF";

        case "ADMIN_EMS_BESS_COORD_ON"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "EMS";
            Class_entry.ADMIN_EMS = "BESS_COORD_ON";

        case "ADMIN_EMS_BESS_COORD_OFF"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "EMS";
            Class_entry.ADMIN_EMS = "BESS_COORD_OFF";

        case "ADMIN_EMS_LOAD_COORD_ON"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "EMS";
            Class_entry.ADMIN_EMS = "LOAD_COORD_ON";

        case "ADMIN_EMS_LOAD_COORD_OFF"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "EMS";
            Class_entry.ADMIN_EMS = "LOAD_COORD_OFF";

        case "ADMIN_EMS_OTHER"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "EMS";
            Class_entry.ADMIN_EMS = "EMS_OTHER";

        % =============================================================
        % ADMIN - BROADCAST
        % =============================================================
        case "ADMIN_BROADCAST_MSG_NOT_READY"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "BROADCAST";
            Class_entry.ADMIN_BRD = "MSG_NOT_READY";

        case "ADMIN_BROADCAST_MSG_READY"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "BROADCAST";
            Class_entry.ADMIN_BRD = "MSG_READY";

        case "ADMIN_BROADCAST_ABORT"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "BROADCAST";
            Class_entry.ADMIN_BRD = "ABORT";

        case "ADMIN_BROADCAST_OTHER"
            Class_entry.MAIN      = "ADMIN";
            Class_entry.ADMIN     = "BROADCAST";
            Class_entry.ADMIN_BRD = "OTHER";

        otherwise
            % Safe fallback preserving the existing data format
            warning("CerBot:InvalidSingleStageRoute", ...
                "Unexpected Single-Stage classifier output: %s. Falling back to CLASSLESS.", ...
                route);

            Class_entry = Class_list_Template;
            Class_entry.MAIN = "CLASSLESS";
            Valid_Route = false;
    end
end
