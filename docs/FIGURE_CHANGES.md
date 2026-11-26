# Confusion-matrix figure revision

The reviewer requested numerical class-index order and larger fonts. The revised evaluator explicitly applies the original input class order to the chart, enlarges figures, ticks, labels, cell values and the numbered class legend, and uses a white-to-blue scale with contrasting cell text. Percentage units are stated in the title/colorbar; redundant percent symbols are removed from individual cells.

The function signature, plot_ON selection, matrix calculation, numerical metrics and returned result structure are unchanged. For example, [0 1 0 0] selects the normalized numeric figure. Each selected figure is exported to Confusion_Matrix_Figures under the current working directory as SVG, PDF and PNG at 600 dpi. File names include classifierType and modelName.

The export calls use print with -dsvg/-dpdf and -vector, and -dpng with -r600. They avoid exportgraphics SVG support, which requires MATLAB R2025a or later. The explicit sortClasses order is supported since R2018b. Use an SVG in Word, or the high-resolution PNG if the document workflow requires a raster image. Keep the figure at a readable page width.

The original and modified source sections for confusion-matrix calculation, all numerical metrics and returned outputs were compared and are identical. MATLAB rendering was not executed in the preparation environment.
