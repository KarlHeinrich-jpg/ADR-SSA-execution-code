clc;
clear;
close all;

%% =========================================================
% 1. Basic settings
%% =========================================================
FONT_NAME = 'Times New Roman';

% 你的 WBDP / PVDP 结果 Excel 所在文件夹
data_dir = fullfile(pwd, 'WBDP_PVDP_PaperStyle');

% 输出图片文件夹
out_dir = fullfile(pwd, 'WBDP_PVDP_ADR_SSA_BestCurve');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% 问题名称
problem_names = {'WBDP', 'PVDP'};

% 只画主算法 ADR-SSA
alg_name_plot = 'ADR-SSA';
alg_name_var  = 'ADR_SSA';

% 主算法颜色和样式
main_color = [214, 39, 40] / 255;   % 红色
line_style = '-';
marker_style = 'o';

%% =========================================================
% 2. Loop over WBDP and PVDP
%% =========================================================
for p = 1:numel(problem_names)

    problem_name = problem_names{p};
    excel_file = fullfile(data_dir, sprintf('%s_results.xlsx', problem_name));

    if ~exist(excel_file, 'file')
        warning('File not found: %s', excel_file);
        continue;
    end

    fprintf('Plotting %s from %s\n', problem_name, excel_file);

    %% -----------------------------------------------------
    % Read BestRunCurve
    %% -----------------------------------------------------
    T_curve = readtable(excel_file, 'Sheet', 'BestRunCurve');

    if ~ismember('Iteration', T_curve.Properties.VariableNames)
        error('Column "Iteration" not found in BestRunCurve sheet of %s.', problem_name);
    end

    if ~ismember(alg_name_var, T_curve.Properties.VariableNames)
        error('Column "%s" not found in BestRunCurve sheet of %s.', alg_name_var, problem_name);
    end

    iterations = T_curve.Iteration;
    best_curve = T_curve.(alg_name_var);
    Max_iteration = numel(iterations);

    %% -----------------------------------------------------
    % Plot ADR-SSA best convergence curve
    %% -----------------------------------------------------
    fig = figure('Color', 'w', 'Position', [100, 100, 760, 560]);
    ax = axes;
    hold(ax, 'on');

    marker_idx = round(linspace(1, Max_iteration, 12));

    [use_log_curve, ymin_curve, ymax_curve, eps_floor_curve] = adaptive_axis_info(best_curve);

    y = best_curve(:);

    if use_log_curve
        y_plot = y;
        y_plot(~isfinite(y_plot) | y_plot <= 0) = eps_floor_curve;

        plot(iterations, y_plot, ...
            'LineWidth', 3.5, ...
            'LineStyle', line_style, ...
            'Color', main_color, ...
            'Marker', marker_style, ...
            'MarkerIndices', marker_idx, ...
            'MarkerSize', 7, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', main_color);
    else
        plot(iterations, y, ...
            'LineWidth', 3.5, ...
            'LineStyle', line_style, ...
            'Color', main_color, ...
            'Marker', marker_style, ...
            'MarkerIndices', marker_idx, ...
            'MarkerSize', 7, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', main_color);
    end

    set(ax, ...
        'FontName', FONT_NAME, ...
        'FontSize', 18, ...
        'LineWidth', 1.8, ...
        'Box', 'on', ...
        'TickDir', 'out', ...
        'XMinorTick', 'off', ...
        'YMinorTick', 'off');

    xlabel('Iteration', 'FontName', FONT_NAME, 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Best Fitness Value', 'FontName', FONT_NAME, 'FontSize', 20, 'FontWeight', 'bold');
    title(sprintf('%s', problem_name), ...
        'FontName', FONT_NAME, 'FontSize', 21, 'FontWeight', 'bold');

    legend(alg_name_plot, ...
        'Location', 'northeast', ...
        'FontName', FONT_NAME, ...
        'FontSize', 15, ...
        'Box', 'on');

    xlim([min(iterations), max(iterations)]);

    if use_log_curve
        set(ax, 'YScale', 'log');
        ylim([ymin_curve, ymax_curve]);
        tick_exp = floor(log10(ymin_curve)) : ceil(log10(ymax_curve));
        yticks(10.^tick_exp);
    else
        set(ax, 'YScale', 'linear');
        ylim([ymin_curve, ymax_curve]);
    end

    ax.XColor = 'black';
    ax.YColor = 'black';
    grid(ax, 'off');

    % 保存 PNG 和 PDF
    exportgraphics(fig, fullfile(out_dir, sprintf('%s_ADR_SSA_BestRunCurve.png', problem_name)), 'Resolution', 400);
    exportgraphics(fig, fullfile(out_dir, sprintf('%s_ADR_SSA_BestRunCurve.pdf', problem_name)), 'ContentType', 'vector');

    close(fig);
end

fprintf('\nAll ADR-SSA best-run convergence plots have been saved to:\n%s\n', out_dir);

%% =========================================================
% Local function: adaptive axis decision
%% =========================================================
function [use_log, ymin_use, ymax_use, eps_floor] = adaptive_axis_info(vals)

vals = vals(:);
vals = vals(isfinite(vals));

pos_vals = vals(vals > 0);

if isempty(pos_vals)
    use_log = false;
    eps_floor = 1e-12;
    ymin_use = min(vals);
    ymax_use = max(vals);

    if isempty(ymin_use) || isempty(ymax_use) || ymin_use == ymax_use
        ymin_use = 0;
        ymax_use = 1;
    else
        pad = 0.08 * (ymax_use - ymin_use);
        ymin_use = ymin_use - pad;
        ymax_use = ymax_use + pad;
    end
    return;
end

ratio_val = max(pos_vals) / max(min(pos_vals), eps);
eps_floor = max(min(pos_vals) * 0.1, 1e-12);

if ratio_val >= 1e2
    use_log = true;
    ymin_use = 10^(floor(log10(min(pos_vals))));
    ymax_use = 10^(ceil(log10(max(pos_vals))));
else
    use_log = false;
    ymin_use = min(vals);
    ymax_use = max(vals);

    if ymin_use == ymax_use
        if ymin_use == 0
            ymax_use = 1;
        else
            ymin_use = ymin_use * 0.9;
            ymax_use = ymax_use * 1.1;
        end
    else
        pad = 0.08 * (ymax_use - ymin_use);
        ymin_use = ymin_use - pad;
        ymax_use = ymax_use + pad;
    end
end
end