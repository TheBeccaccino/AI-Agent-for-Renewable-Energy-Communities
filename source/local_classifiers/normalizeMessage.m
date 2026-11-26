function s = normalizeMessage(raw)
    s = lower(strtrim(string(raw)));
    s = replace(s, ["à", "á", "â", "ä"], "a");
    s = replace(s, ["è", "é", "ê", "ë"], "e");
    s = replace(s, ["ì", "í", "î", "ï"], "i");
    s = replace(s, ["ò", "ó", "ô", "ö"], "o");
    s = replace(s, ["ù", "ú", "û", "ü"], "u");
    s = regexprep(s, "[^a-z0-9:%]+", " ");
    s = regexprep(s, "\s+", " ");
    s = strtrim(s);
end