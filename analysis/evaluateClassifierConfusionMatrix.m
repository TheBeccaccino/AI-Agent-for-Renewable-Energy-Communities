function results = evaluateClassifierConfusionMatrix(yTrue, yPred, classNames, modelName, classifierType, plot_ON)
% evaluateClassifierConfusionMatrix
%
% Calcola, visualizza e analizza la confusion matrix di un classificatore.
% Genera quattro figure:
%   1) Confusion Matrix con assi numerici e legenda classi sottostante
%   2) Confusion Matrix normalizzata (%) con assi numerici e legenda classi sottostante
%   3) Confusion Matrix con nomi classe sugli assi
%   4) Confusion Matrix normalizzata (%) con nomi classe sugli assi
%
% Tutte le scritte sono in grassetto.
% Titolo e label degli assi sono in Times New Roman.
% Gli indici seguono l'ordine 1, 2, ..., N, coerente con classIndexTable.
% Le figure attive vengono salvate in Confusion_Matrix_Figures:
% SVG e PDF vettoriali, PNG a 600 dpi.
%
% INPUT
%   yTrue
%       Etichette corrette.
%       Può essere string array, categorical o cell array di char.
%
%   yPred
%       Etichette predette dal classificatore.
%       Può essere string array, categorical o cell array di char.
%
%   classNames
%       Elenco ordinato di tutte le classi da considerare.
%
%   modelName
%       Nome del modello utilizzato (es. "gpt-5-nano", "gpt-6-luna").
%
%   classifierType
%       Tipo/architettura del classificatore (es. "Local", "Hybrid",
%       "Hierarchical LLM", "Single-stage").
%
%   plot_ON
%       Vettore numerico/logico di quattro elementi:
%           plot_ON(1) -> Confusion Matrix con assi numerici
%           plot_ON(2) -> Confusion Matrix normalizzata con assi numerici
%           plot_ON(3) -> Confusion Matrix con nomi classe
%           plot_ON(4) -> Confusion Matrix normalizzata con nomi classe
%       Per il paper: [0 1 0 0] genera la matrice normalizzata in %
%       con assi numerici e legenda classi sottostante.
%
% OUTPUT
%   results
%       Struttura contenente:
%           confusionMatrix
%           normalizedConfusionMatrix
%           classNames
%           classIndexTable
%           accuracy
%           balancedAccuracy
%           macroPrecision
%           macroRecall
%           macroF1
%           weightedF1
%           metricsTable
%           figureHandles

    %% Impostazioni grafiche
    plotFontName = 'Times New Roman';
    plotFontWeight = 'bold';
    plotFontSize = 13;
    plotTitleFontSize = 14;
    plotColorMap = [linspace(1, 0.08, 256)', ...
                    linspace(1, 0.24, 256)', ...
                    linspace(1, 0.48, 256)'];

    %% Controllo input

    if nargin < 5
        error(['La funzione richiede almeno cinque input: ', ...
               'yTrue, yPred, classNames, modelName e classifierType.']);
    end

    if nargin < 6 || isempty(plot_ON)
        plot_ON = [1 1 1 1];
    end

    if ~isnumeric(plot_ON) && ~islogical(plot_ON)
        error('plot_ON deve essere un vettore numerico o logico di quattro elementi.');
    end

    if numel(plot_ON) ~= 4
        error('plot_ON deve contenere esattamente quattro elementi.');
    end

    plot_ON = logical(plot_ON(:).');

    modelName = string(modelName);
    classifierType = string(classifierType);

    if ~isscalar(modelName) || ~isscalar(classifierType)
        error('modelName e classifierType devono essere valori scalari.');
    end

    %% Conversione in string array

    yTrue = string(yTrue);
    yPred = string(yPred);
    classNames = string(classNames);

    yTrue = yTrue(:);
    yPred = yPred(:);
    classNames = classNames(:);

    %% Controlli di base

    if isempty(yTrue)
        error('yTrue è vuoto.');
    end

    if isempty(yPred)
        error('yPred è vuoto.');
    end

    if isempty(classNames)
        error('classNames è vuoto.');
    end

    if numel(yTrue) ~= numel(yPred)
        error('yTrue e yPred devono contenere lo stesso numero di elementi.');
    end

    yTrue = strtrim(yTrue);
    yPred = strtrim(yPred);
    classNames = strtrim(classNames);

    if numel(unique(classNames)) ~= numel(classNames)
        error('classNames contiene classi duplicate.');
    end

    unknownTrue = setdiff(unique(yTrue), classNames);
    unknownPred = setdiff(unique(yPred), classNames);

    if ~isempty(unknownTrue)
        error('Classi reali non presenti in classNames: %s', ...
              strjoin(unknownTrue, ', '));
    end

    if ~isempty(unknownPred)
        error('Classi predette non presenti in classNames: %s', ...
              strjoin(unknownPred, ', '));
    end

    %% Preparazione categorical con ordine esplicito

    yTrueCategorical = categorical(yTrue, classNames, classNames);
    yPredCategorical = categorical(yPred, classNames, classNames);
    classOrder = categorical(classNames, classNames, classNames);

    %% Confusion matrix numerica

    confusionMatrix = confusionmat( ...
        yTrueCategorical, ...
        yPredCategorical, ...
        'Order', classOrder);

    %% Confusion matrix normalizzata per riga

    rowTotals = sum(confusionMatrix, 2);

    normalizedConfusionMatrix = zeros(size(confusionMatrix));

    validRows = rowTotals > 0;
    normalizedConfusionMatrix(validRows, :) = ...
        confusionMatrix(validRows, :) ./ rowTotals(validRows);

    %% Etichette asse numeriche e nominali

    numClasses = numel(classNames);

    numericAxisLabels = string(1:numClasses);
    numericAxisLabelsCell = cellstr(numericAxisLabels);

    namedAxisLabelsCell = cellstr(classNames);

    %% Titoli figure
    titleSuffix = " - " + classifierType + " - " + modelName;

    %% Tabella di mapping indice -> nome classe

    classIndexTable = table( ...
        (1:numClasses)', ...
        classNames, ...
        'VariableNames', {'Index', 'ClassName'});

    %% Inizializzazione handle figure
    fig1 = [];
    fig2 = [];
    fig3 = [];
    fig4 = [];

    %% Figure 1: counts con assi numerici
    if plot_ON(1)
        fig1 = figure( ...
            'Name', char("Confusion Matrix - Numeric Labels" + titleSuffix), ...
            'NumberTitle', 'off', ...
            'Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [1 1 22 27]);

        chart1 = confusionchart(confusionMatrix, numericAxisLabelsCell);
        % Impedisce l'ordinamento alfabetico 1, 10, 11, ..., 2, 20, ...
        sortClasses(chart1, numericAxisLabelsCell);
        chart1.Title = sprintf('Confusion matrix\n%s | %s', classifierType, modelName);
        chart1.XLabel = 'Predicted Class Index';
        chart1.YLabel = 'True Class Index';

        try
            chart1.RowSummary = 'row-normalized';
        catch
        end

        try
            chart1.ColumnSummary = 'column-normalized';
        catch
        end

        applyChartStyle(chart1, plotFontName, plotFontWeight, plotFontSize);

        % Legenda numerata delle classi in un riquadro sotto la matrice.
        % La legenda viene aggiunta solo alle figure con assi numerici.
        addNumberedClassLegend( ...
            fig1, chart1, classNames, plotFontName, plotFontWeight);
    end

    %% Figure 2: normalized con assi numerici - percentuali nelle celle
    if plot_ON(2)
        fig2 = figure( ...
            'Name', char("Normalized Confusion Matrix - Numeric Labels" + titleSuffix), ...
            'NumberTitle', 'off', ...
            'Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [1 1 22 27]);

        % La matrice viene visualizzata direttamente in percentuale.
        % In questo modo il contenuto delle celle e' sempre espresso come
        % quota della TRUE class, evitando i conteggi assoluti.
        percentageMatrix = 100 .* normalizedConfusionMatrix;

        ax2 = axes('Parent', fig2);
        imagesc(ax2, percentageMatrix);
        axis(ax2, 'equal');
        axis(ax2, 'tight');
        caxis(ax2, [0 100]);
        colormap(ax2, plotColorMap);

        colorBar2 = colorbar(ax2);
        colorBar2.FontName = plotFontName;
        colorBar2.FontWeight = plotFontWeight;
        colorBar2.FontSize = plotFontSize - 1;
        try
            colorBar2.Label.String = 'Percentage of true class (%)';
            colorBar2.Label.FontName = plotFontName;
            colorBar2.Label.FontWeight = plotFontWeight;
        catch
        end

        title(ax2, ...
            {'Row-normalized confusion matrix (%)'; ...
             char(classifierType + " | " + modelName)}, ...
            'FontName', plotFontName, ...
            'FontWeight', plotFontWeight, ...
            'FontSize', plotTitleFontSize, ...
            'Interpreter', 'none');

        xlabel(ax2, 'Predicted Class Index', ...
            'FontName', plotFontName, 'FontWeight', plotFontWeight, ...
            'FontSize', plotFontSize);
        ylabel(ax2, 'True Class Index', ...
            'FontName', plotFontName, 'FontWeight', plotFontWeight, ...
            'FontSize', plotFontSize);

        xticks(ax2, 1:numClasses);
        yticks(ax2, 1:numClasses);
        xticklabels(ax2, numericAxisLabelsCell);
        yticklabels(ax2, numericAxisLabelsCell);

        set(ax2, ...
            'FontName', plotFontName, ...
            'FontWeight', plotFontWeight, ...
            'FontSize', plotFontSize, ...
            'TickLabelInterpreter', 'none', ...
            'TickLength', [0 0]);

        % Mostra nelle celle solamente le percentuali non nulle.
        % Lo zero viene lasciato vuoto per rendere leggibile una matrice
        % con molte classi.
        addPercentageValues(ax2, percentageMatrix, ...
            plotFontName, plotFontWeight);

        % Legenda numerata delle classi in un riquadro sotto la matrice.
        addNumberedClassLegend( ...
            fig2, ax2, classNames, plotFontName, plotFontWeight);
        colorBar2.Position = [0.89 0.33 0.025 0.59];
    end

    %% Figure 3: counts con nomi classe
    if plot_ON(3)
        fig3 = figure( ...
            'Name', char("Confusion Matrix - Class Names" + titleSuffix), ...
            'NumberTitle', 'off', ...
            'Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [1 1 28 27]);

        chart3 = confusionchart(confusionMatrix, namedAxisLabelsCell);
        sortClasses(chart3, namedAxisLabelsCell);
        chart3.Title = sprintf('Confusion matrix\n%s | %s', classifierType, modelName);
        chart3.XLabel = 'Predicted Class';
        chart3.YLabel = 'True Class';

        try
            chart3.RowSummary = 'row-normalized';
        catch
        end

        try
            chart3.ColumnSummary = 'column-normalized';
        catch
        end

        applyChartStyle(chart3, plotFontName, plotFontWeight, plotFontSize);
    end

    %% Figure 4: normalized con nomi classe - percentuali nelle celle
    if plot_ON(4)
        fig4 = figure( ...
            'Name', char("Normalized Confusion Matrix - Class Names" + titleSuffix), ...
            'NumberTitle', 'off', ...
            'Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [1 1 28 27]);

        percentageMatrix = 100 .* normalizedConfusionMatrix;

        ax4 = axes('Parent', fig4);
        imagesc(ax4, percentageMatrix);
        axis(ax4, 'equal');
        axis(ax4, 'tight');
        caxis(ax4, [0 100]);
        colormap(ax4, plotColorMap);

        colorBar4 = colorbar(ax4);
        colorBar4.FontName = plotFontName;
        colorBar4.FontWeight = plotFontWeight;
        colorBar4.FontSize = plotFontSize - 1;
        try
            colorBar4.Label.String = 'Percentage of true class (%)';
            colorBar4.Label.FontName = plotFontName;
            colorBar4.Label.FontWeight = plotFontWeight;
        catch
        end

        title(ax4, ...
            {'Row-normalized confusion matrix (%)'; ...
             char(classifierType + " | " + modelName)}, ...
            'FontName', plotFontName, ...
            'FontWeight', plotFontWeight, ...
            'FontSize', plotTitleFontSize, ...
            'Interpreter', 'none');

        xlabel(ax4, 'Predicted Class', ...
            'FontName', plotFontName, 'FontWeight', plotFontWeight, ...
            'FontSize', plotFontSize);
        ylabel(ax4, 'True Class', ...
            'FontName', plotFontName, 'FontWeight', plotFontWeight, ...
            'FontSize', plotFontSize);

        xticks(ax4, 1:numClasses);
        yticks(ax4, 1:numClasses);
        xticklabels(ax4, namedAxisLabelsCell);
        yticklabels(ax4, namedAxisLabelsCell);
        xtickangle(ax4, 45);

        set(ax4, ...
            'FontName', plotFontName, ...
            'FontWeight', plotFontWeight, ...
            'FontSize', plotFontSize, ...
            'TickLabelInterpreter', 'none', ...
            'TickLength', [0 0]);
        ax4.Position = [0.25 0.25 0.64 0.65];
        colorBar4.Position = [0.92 0.25 0.02 0.65];

        addPercentageValues(ax4, percentageMatrix, ...
            plotFontName, plotFontWeight);
    end

    %% Esportazione delle sole figure richieste
    % La figura intera include anche la legenda indice -> classe.
    if any(plot_ON)
        Figure_Folder = fullfile(pwd, 'Confusion_Matrix_Figures');
        if ~isfolder(Figure_Folder)
            mkdir(Figure_Folder)
        end
        Figure_List = {fig1, fig2, fig3, fig4};
        Figure_Names = ["counts_numeric", "normalized_numeric", ...
                        "counts_names", "normalized_names"];
        File_Prefix = regexprep(char(classifierType + "_" + modelName), ...
            '[^a-zA-Z0-9_-]+', '_');
        for F = find(plot_ON)
            Figure = Figure_List{F};
            drawnow;
            Figure.PaperUnits = 'centimeters';
            Figure.PaperSize = Figure.Position(3:4);
            Figure.PaperPosition = [0 0 Figure.Position(3:4)];
            File_Name = fullfile(Figure_Folder, ...
                [File_Prefix, '_', char(Figure_Names(F))]);
            print(Figure, [File_Name, '.svg'], '-dsvg', '-vector');
            print(Figure, [File_Name, '.pdf'], '-dpdf', '-vector');
            print(Figure, [File_Name, '.png'], '-dpng', '-r600');
        end
    end

    %% Metriche globali

    totalSamples = sum(confusionMatrix(:));
    correctPredictions = trace(confusionMatrix);

    accuracy = correctPredictions / totalSamples;

    %% Metriche per classe

    truePositive = diag(confusionMatrix);
    falsePositive = sum(confusionMatrix, 1)' - truePositive;
    falseNegative = sum(confusionMatrix, 2) - truePositive;
    trueNegative = totalSamples - truePositive - falsePositive - falseNegative;

    precision = safeDivide(truePositive, truePositive + falsePositive);
    recall = safeDivide(truePositive, truePositive + falseNegative);
    specificity = safeDivide(trueNegative, trueNegative + falsePositive);
    f1Score = safeDivide(2 .* precision .* recall, precision + recall);

    support = sum(confusionMatrix, 2);

    %% Metriche aggregate

    macroPrecision = meanIgnoringNaN(precision);
    macroRecall = meanIgnoringNaN(recall);
    macroF1 = meanIgnoringNaN(f1Score);

    balancedAccuracy = macroRecall;

    validWeightedClasses = support > 0 & ~isnan(f1Score);

    if any(validWeightedClasses)
        weightedF1 = sum( ...
            f1Score(validWeightedClasses) .* support(validWeightedClasses)) ...
            / sum(support(validWeightedClasses));
    else
        weightedF1 = NaN;
    end

    %% Tabella metriche

    metricsTable = table( ...
        (1:numClasses)', ...
        classNames, ...
        support, ...
        truePositive, ...
        falsePositive, ...
        falseNegative, ...
        trueNegative, ...
        precision, ...
        recall, ...
        specificity, ...
        f1Score, ...
        'VariableNames', { ...
            'Index', ...
            'Class', ...
            'Support', ...
            'TruePositive', ...
            'FalsePositive', ...
            'FalseNegative', ...
            'TrueNegative', ...
            'Precision', ...
            'Recall', ...
            'Specificity', ...
            'F1Score'});


    writetable( ...
    metricsTable, ...
    'classification_metrics.xlsx');
    %% Output

    results = struct();

    results.confusionMatrix = confusionMatrix;
    results.normalizedConfusionMatrix = normalizedConfusionMatrix;
    results.classNames = classNames;
    results.classIndexTable = classIndexTable;
    results.modelName = modelName;
    results.classifierType = classifierType;
    results.plot_ON = plot_ON;

    results.accuracy = accuracy;
    results.balancedAccuracy = balancedAccuracy;
    results.macroPrecision = macroPrecision;
    results.macroRecall = macroRecall;
    results.macroF1 = macroF1;
    results.weightedF1 = weightedF1;

    results.metricsTable = metricsTable;

    results.figureHandles = struct();
    results.figureHandles.countsNumeric = fig1;
    results.figureHandles.normalizedNumeric = fig2;
    results.figureHandles.countsNames = fig3;
    results.figureHandles.normalizedNames = fig4;

    %% Stampa risultati

    fprintf('\n');
    fprintf('========================================\n');
    fprintf(' RISULTATI DEL CLASSIFICATORE\n');
    fprintf('========================================\n');
    fprintf('Classificatore:              %s\n', char(classifierType));
    fprintf('Modello:                     %s\n', char(modelName));
    fprintf('Numero totale di campioni:   %d\n', totalSamples);
    fprintf('Predizioni corrette:       %d\n', correctPredictions);
    fprintf('Accuracy:                  %.4f\n', accuracy);
    fprintf('Balanced accuracy:         %.4f\n', balancedAccuracy);
    fprintf('Macro precision:           %.4f\n', macroPrecision);
    fprintf('Macro recall:              %.4f\n', macroRecall);
    fprintf('Macro F1-score:            %.4f\n', macroF1);
    fprintf('Weighted F1-score:         %.4f\n', weightedF1);
    fprintf('========================================\n\n');

    disp(metricsTable);
    fprintf('\nTabella indice -> classe:\n');
    disp(classIndexTable);

end


function applyChartStyle(chartObj, fontName, fontWeight, fontSize)
% Applica stile grafico al confusionchart.
    try
        chartObj.FontName = fontName;
    catch
    end

    try
        chartObj.FontWeight = fontWeight;
    catch
    end
    chartObj.FontSize = fontSize;
end


function result = safeDivide(numerator, denominator)
% Esegue la divisione evitando problemi con denominatori nulli.
    result = numerator ./ denominator;
    result(denominator == 0) = NaN;
end


function averageValue = meanIgnoringNaN(values)
% Calcola la media ignorando i NaN.
    validValues = values(~isnan(values));

    if isempty(validValues)
        averageValue = NaN;
    else
        averageValue = mean(validValues);
    end
end


function addNumberedClassLegend(figHandle, plotObject, classNames, fontName, fontWeight)
%ADDNUMBEREDCLASSLEGEND Aggiunge una legenda indice -> classe sotto la figura.
%
% La legenda e' pensata per le confusion matrix con assi numerici. Viene
% disposta automaticamente su 1-3 colonne all'interno di un unico riquadro.
% La funzione prova inoltre a lasciare spazio sotto il grafico senza
% dipendere dal tipo specifico di oggetto grafico (confusionchart o axes).

    classNames = string(classNames(:));
    numClasses = numel(classNames);

    if numClasses == 0 || isempty(figHandle) || ~isgraphics(figHandle)
        return
    end

    %% Dimensione figura fissata per mantenere leggibili i caratteri
    try
        oldUnits = figHandle.Units;
        figHandle.Units = 'centimeters';
        figPosition = figHandle.Position;
        figPosition(3:4) = [22 27];
        figHandle.Position = figPosition;
        figHandle.Units = oldUnits;
    catch
        % La legenda viene comunque aggiunta anche se la dimensione della
        % finestra non puo' essere modificata.
    end

    %% Riserva la parte inferiore della figura alla legenda
    legendBottom = 0.025;
    legendHeight = 0.23;
    legendLeft = 0.055;
    legendWidth = 0.89;

    % Prova a spostare/ridimensionare il grafico verso l'alto. Le diverse
    % versioni MATLAB espongono proprieta' leggermente diverse, quindi ogni
    % operazione e' protetta da try/catch.
    try
        plotObject.Position = [0.12, 0.33, 0.74, 0.59];
    catch
        try
            plotObject.OuterPosition = [0.05, 0.30, 0.90, 0.66];
        catch
        end
    end

    %% Riquadro esterno della legenda
    try
        annotation( ...
            figHandle, ...
            'rectangle', ...
            [legendLeft, legendBottom, legendWidth, legendHeight], ...
            'LineWidth', 0.8, ...
            'LineStyle', '-', ...
            'FaceColor', [1 1 1]);
    catch
        % Alcune release meno recenti non accettano FaceColor per rectangle.
        annotation( ...
            figHandle, ...
            'rectangle', ...
            [legendLeft, legendBottom, legendWidth, legendHeight], ...
            'LineWidth', 0.8, ...
            'LineStyle', '-');
    end

    %% Titolo della legenda
    annotation( ...
        figHandle, ...
        'textbox', ...
        [legendLeft + 0.015, legendBottom + legendHeight - 0.055, ...
         legendWidth - 0.03, 0.04], ...
        'String', 'Class index legend', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontName', fontName, ...
        'FontWeight', fontWeight, ...
        'FontSize', 12, ...
        'LineStyle', 'none', ...
        'Interpreter', 'none');

    %% Numero di colonne automatico
    if numClasses <= 8
        numColumns = 1;
    elseif numClasses <= 16
        numColumns = 2;
    else
        numColumns = 3;
    end

    rowsPerColumn = ceil(numClasses / numColumns);
    columnGap = 0.018;
    usableWidth = legendWidth - 0.04;
    columnWidth = (usableWidth - (numColumns - 1) * columnGap) / numColumns;
    textBottom = legendBottom + 0.015;
    textHeight = legendHeight - 0.075;

    for columnIndex = 1:numColumns
        firstIndex = (columnIndex - 1) * rowsPerColumn + 1;
        lastIndex = min(columnIndex * rowsPerColumn, numClasses);

        if firstIndex > numClasses
            break
        end

        entries = strings(lastIndex - firstIndex + 1, 1);
        entryCounter = 1;
        for classIndex = firstIndex:lastIndex
            entries(entryCounter) = sprintf('%2d  -  %s', ...
                classIndex, classNames(classIndex));
            entryCounter = entryCounter + 1;
        end

        columnText = strjoin(entries, newline);
        columnLeft = legendLeft + 0.02 + ...
            (columnIndex - 1) * (columnWidth + columnGap);

        annotation( ...
            figHandle, ...
            'textbox', ...
            [columnLeft, textBottom, columnWidth, textHeight], ...
            'String', char(columnText), ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'top', ...
            'FontName', fontName, ...
            'FontWeight', fontWeight, ...
            'FontSize', 11, ...
            'LineStyle', 'none', ...
            'Interpreter', 'none', ...
            'FitBoxToText', 'off');
    end
end


function addPercentageValues(axHandle, percentageMatrix, fontName, fontWeight)
%ADDPERCENTAGEVALUES Scrive percentuali nelle celle della confusion matrix.
%
% I valori sono gia' attesi nell'intervallo [0,100]. Le celle pari a zero
% vengono lasciate vuote per limitare l'affollamento grafico. I valori
% vengono mostrati con una cifra decimale solo quando necessaria.
% L'unita' percentuale e' indicata nel titolo e nella barra dei colori.

    [numberOfRows, numberOfColumns] = size(percentageMatrix);

    % Dimensione font leggermente adattiva per matrici dense.
    maxDimension = max(numberOfRows, numberOfColumns);
    if maxDimension >= 20
        valueFontSize = 10;
    elseif maxDimension >= 15
        valueFontSize = 11;
    else
        valueFontSize = 12;
    end

    for rowIndex = 1:numberOfRows
        for columnIndex = 1:numberOfColumns
            value = percentageMatrix(rowIndex, columnIndex);

            % Non stampare gli zeri: rende molto piu' leggibili matrici
            % sparse con molte classi.
            if abs(value) < 0.05
                continue
            end

            % Testo bianco sulle celle piu' intense, nero sulle altre.
            if value >= 70
                textColor = [1 1 1];
            else
                textColor = [0 0 0];
            end

            if abs(value - round(value)) < 0.05
                valueLabel = sprintf('%.0f', value);
            else
                valueLabel = sprintf('%.1f', value);
            end

            text( ...
                axHandle, ...
                columnIndex, ...
                rowIndex, ...
                valueLabel, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontName', fontName, ...
                'FontWeight', fontWeight, ...
                'FontSize', valueFontSize, ...
                'Color', textColor, ...
                'Interpreter', 'none');
        end
    end
end


function addMatrixValues(matrixValues, numberFormat, fontName, fontWeight)
% Mostra il valore numerico all'interno di ogni cella della matrice.
    [numberOfRows, numberOfColumns] = size(matrixValues);

    for rowIndex = 1:numberOfRows
        for columnIndex = 1:numberOfColumns
            value = matrixValues(rowIndex, columnIndex);

            text( ...
                columnIndex, ...
                rowIndex, ...
                sprintf(numberFormat, value), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontName', fontName, ...
                'FontWeight', fontWeight);
        end
    end
end
