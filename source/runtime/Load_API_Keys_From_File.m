function Load_API_Keys_From_File(fileName)
%LOAD_API_KEYS_FROM_FILE
% Legge le API key da un file di testo e le carica come variabili
% d'ambiente valide per la sessione MATLAB corrente.
%
% Formato atteso:
%
%   OPENAI_API_KEY=...
%   ANTHROPIC_API_KEY=...
%
% Le chiavi non vengono mai stampate a console.
%
% Uso:
%   Load_API_Keys_From_File
%
% oppure:
%   Load_API_Keys_From_File("percorso/api_keys.txt")


    %% File di default
    if nargin < 1 || strlength(string(fileName)) == 0

        % Cerca api_keys.txt nella stessa cartella di questa funzione
        thisFile = mfilename("fullpath");
        projectFolder = fileparts(thisFile);

        fileName = fullfile(projectFolder, "api_keys.txt");
    end


    %% Controllo esistenza file
    if ~isfile(fileName)
        error( ...
            "Load_API_Keys_From_File:FileNotFound", ...
            "File delle API key non trovato: %s", ...
            fileName);
    end


    %% Lettura file
    fileContent = string(fileread(fileName));
    lines = splitlines(fileContent);


    %% Variabili richieste
    Required_Keys = [ ...
        "OPENAI_API_KEY", ...
        "ANTHROPIC_API_KEY" ...
    ];

    Key_Found = false(size(Required_Keys));


    %% Parsing
    for i = 1:numel(lines)

        line = strtrim(lines(i));

        % Ignora righe vuote
        if strlength(line) == 0
            continue
        end

        % Ignora commenti
        if startsWith(line, "#")
            continue
        end


        %% Cerca il primo =
        eqPosition = strfind(char(line), "=");

        if isempty(eqPosition)
            warning( ...
                "Riga ignorata nel file API key: formato non valido.");
            continue
        end

        eqPosition = eqPosition(1);

        keyName = strtrim(extractBefore(line, eqPosition));
        keyValue = strtrim(extractAfter(line, eqPosition));


        %% Ignora campi non previsti
        keyIndex = find(Required_Keys == keyName, 1);

        if isempty(keyIndex)
            continue
        end


        %% Controllo valore
        if strlength(keyValue) == 0
            error( ...
                "Load_API_Keys_From_File:EmptyKey", ...
                "La chiave %s è presente ma vuota.", ...
                keyName);
        end


        %% Caricamento variabile d'ambiente
        setenv(char(keyName), char(keyValue));

        Key_Found(keyIndex) = true;

    end


    %% Verifica finale
    Missing_Keys = Required_Keys(~Key_Found);

    if ~isempty(Missing_Keys)

        error( ...
            "Load_API_Keys_From_File:MissingKeys", ...
            "Nel file mancano le seguenti chiavi: %s", ...
            strjoin(Missing_Keys, ", "));
    end


    fprintf("API keys caricate correttamente.\n");

end