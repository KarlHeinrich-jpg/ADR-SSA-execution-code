clc;
clear;
close all;

%% =========================================================
% 1. Basic settings
%% =========================================================
SearchAgents_no = 30;   % population size
dim = 10;               % CEC2022: only 2, 10, 20 are supported
Max_iteration = 1000;    % iterations
lb = -100;              % lower bound
ub = 100;               % upper bound
runs = 10;              % number of independent runs

Function_name = 12;      % choose one function only, e.g. 1~12
fhd = str2func('cec22_func');

% ===== SSA comparison models =====
alg_names_plot = {'SSA', 'ADR-SSA'};
alg_names_var  = {'SSA', 'ADR_SSA'};
alg_num = numel(alg_names_plot);

% objective function: cec22_func expects column vector
fobj = @(x) fhd(x(:), Function_name);

%% =========================================================
% 2. Output folder
%% =========================================================
out_dir = fullfile(pwd, sprintf('CEC2022_F%d_SSA_Comparison', Function_name));
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

excel_file = fullfile(out_dir, sprintf('F%d_SSA_comparison_results.xlsx', Function_name));

%% =========================================================
% 3. Result containers
%% =========================================================
best_results  = zeros(runs, alg_num);
curve_results = zeros(Max_iteration, runs, alg_num);

%% =========================================================
% 4. Run experiments
%% =========================================================
for a = 1:alg_num
    fprintf('\n==============================\n');
    fprintf('Algorithm: %s\n', alg_names_plot{a});
    fprintf('Function : F%d\n', Function_name);
    fprintf('==============================\n');

    for r = 1:runs
        rng(r, 'twister');

        switch alg_names_plot{a}
            case 'SSA'
                [Best_score, ~, cg_curve] = ...
                    SSA(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);

            case 'ADR-SSA'
                [Best_score, ~, cg_curve] = ...
                    ADR_SSA(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        end

        cg_curve = normalize_curve(cg_curve, Max_iteration);

        best_results(r, a) = Best_score;
        curve_results(:, r, a) = cg_curve;

        fprintf('Run %02d | Best = %.10e\n', r, Best_score);
    end
end

%% =========================================================
% 5. Statistics
%% =========================================================
mean_curves = squeeze(mean(curve_results, 2));

mean_vals = mean(best_results, 1)';
std_vals  = std(best_results, 0, 1)';

%% =========================================================
% 6. Wilcoxon rank-sum p-value matrix
%% =========================================================
p_matrix = nan(alg_num, alg_num);

for i = 1:alg_num
    for j = 1:alg_num
        if i == j
            p_matrix(i, j) = 1;
        else
            p_matrix(i, j) = ranksum(best_results(:, i), best_results(:, j));
        end
    end
end

%% =========================================================
% 7. Save results to Excel
%% =========================================================

% ---------- Sheet 1: BestResults ----------
best_cell = cell(alg_num, runs + 1);
for a = 1:alg_num
    best_cell{a, 1} = alg_names_plot{a};
    for r = 1:runs
        best_cell{a, r + 1} = best_results(r, a);
    end
end

best_header = cell(1, runs + 1);
best_header{1} = 'Model';
for r = 1:runs
    best_header{r + 1} = sprintf('Run%d', r);
end

T_best = cell2table(best_cell, 'VariableNames', matlab.lang.makeValidName(best_header));
writetable(T_best, excel_file, 'Sheet', 'BestResults');

% ---------- Sheet 2: Statistics ----------
T_stat = table(alg_names_plot', mean_vals, std_vals, ...
    'VariableNames', {'Model', 'Mean', 'Std'});
writetable(T_stat, excel_file, 'Sheet', 'Statistics');

% ---------- Sheet 3: WilcoxonP ----------
p_cell = cell(alg_num, alg_num + 1);
for i = 1:alg_num
    p_cell{i, 1} = alg_names_plot{i};
    for j = 1:alg_num
        p_cell{i, j + 1} = p_matrix(i, j);
    end
end

p_header = [{'Model'}, alg_names_plot];
T_p = cell2table(p_cell, 'VariableNames', matlab.lang.makeValidName(p_header));
writetable(T_p, excel_file, 'Sheet', 'WilcoxonP');

fprintf('\nExcel saved to:\n%s\n', excel_file);

%% =========================================================
% 8. Plot average convergence curves
%% =========================================================
plot_average_convergence(mean_curves, alg_names_plot, ...
    Function_name, dim, Max_iteration, out_dir);

%% =========================================================
% 9. Plot boxplot
%% =========================================================
plot_boxplot_results(best_results, alg_names_plot, Function_name, out_dir);

fprintf('\nFigures saved to:\n%s\n', out_dir);

%% =========================================================
% Local function 1: normalize convergence curve
%% =========================================================
function cg_curve = normalize_curve(cg_curve, Max_iteration)
    cg_curve = cg_curve(:);

    if isempty(cg_curve)
        error('The convergence curve returned by the algorithm is empty.');
    end

    if numel(cg_curve) < Max_iteration
        cg_curve = [cg_curve; repmat(cg_curve(end), Max_iteration - numel(cg_curve), 1)];
    elseif numel(cg_curve) > Max_iteration
        cg_curve = cg_curve(1:Max_iteration);
    end

    cg_curve = cummin(cg_curve);
end

%% =========================================================
% Local function 2: average convergence curves
%% =========================================================
function plot_average_convergence(mean_curves, alg_names_plot, Function_name, dim, Max_iteration, out_dir)

    figure('Color','w', 'Position',[120,100,960,680]);
    ax = axes;
    hold(ax, 'on');

    colors = [
        31 119 180;   % SSA
        214 39 40     % ADR-SSA
    ] / 255;

    line_styles = {':','-'};
    markers = {'o','s'};
    marker_idx = round(linspace(1, Max_iteration, 14));
    iters = 1:Max_iteration;

    all_vals = mean_curves(:);
    all_vals = all_vals(isfinite(all_vals) & all_vals > 0);

    use_log = false;
    if ~isempty(all_vals)
        ratio_val = max(all_vals) / max(min(all_vals), eps);
        if ratio_val > 1e3
            use_log = true;
        end
    end

    h = gobjects(size(mean_curves,2),1);
    for a = 1:size(mean_curves, 2)
        y = mean_curves(:, a);
        y = y(:);

        if use_log
            h(a) = semilogy(iters, y, ...
                'LineWidth', 2.4, ...
                'LineStyle', line_styles{a}, ...
                'Color', colors(a,:), ...
                'Marker', markers{a}, ...
                'MarkerIndices', marker_idx, ...
                'MarkerSize', 6.0, ...
                'MarkerFaceColor', 'w', ...
                'MarkerEdgeColor', colors(a,:));
        else
            h(a) = plot(iters, y, ...
                'LineWidth', 2.4, ...
                'LineStyle', line_styles{a}, ...
                'Color', colors(a,:), ...
                'Marker', markers{a}, ...
                'MarkerIndices', marker_idx, ...
                'MarkerSize', 6.0, ...
                'MarkerFaceColor', 'w', ...
                'MarkerEdgeColor', colors(a,:));
        end
    end

    xlabel('Iteration', ...
        'FontName','Times New Roman', ...
        'FontSize',14, ...
        'FontWeight','bold');

    ylabel('Average Fitness Value', ...
        'FontName','Times New Roman', ...
        'FontSize',14, ...
        'FontWeight','bold');

    title(sprintf('CEC2022-F%d (dim=%d)', Function_name, dim), ...
        'FontName','Times New Roman', ...
        'FontSize',16, ...
        'FontWeight','bold');

    legend(h, alg_names_plot, ...
        'Location','northeast', ...
        'FontName','Times New Roman', ...
        'FontSize',10.5, ...
        'Box','on');

    set(ax, ...
        'FontName','Times New Roman', ...
        'FontSize',12.5, ...
        'LineWidth',1.4, ...
        'Box','on', ...
        'TickDir','out', ...
        'XMinorTick','off', ...
        'YMinorTick','off');

    grid(ax, 'on');
    ax.GridLineStyle = '--';
    ax.GridAlpha = 0.22;

    xlim([1 Max_iteration]);

    if ~use_log
        y_all = mean_curves(:);
        y_all = y_all(isfinite(y_all));
        y_min = min(y_all);
        y_max = max(y_all);
        if y_max > y_min
            pad = 0.08 * (y_max - y_min);
            ylim([y_min - pad, y_max + pad]);
        end
    end

    curve_png = fullfile(out_dir, sprintf('F%d_AverageConvergence.png', Function_name));
    curve_pdf = fullfile(out_dir, sprintf('F%d_AverageConvergence.pdf', Function_name));
    saveas(gcf, curve_png);
    saveas(gcf, curve_pdf);
end

%% =========================================================
% Local function 3: boxplot
%% =========================================================
function plot_boxplot_results(best_results, alg_names_plot, Function_name, out_dir)

    figure('Color','w', 'Position',[140,120,900,650]);

    colors = [
        31 119 180;   % SSA
        214 39 40     % OLNL-SSA
    ] / 255;

    boxplot(best_results, ...
        'Labels', alg_names_plot, ...
        'Symbol', 'r+', ...
        'Whisker', 1.5, ...
        'Widths', 0.60, ...
        'Colors', [0.20 0.20 0.20]);

    ax = gca;
    set(ax, ...
        'FontName','Times New Roman', ...
        'FontSize',12.5, ...
        'LineWidth',1.4, ...
        'Box','on', ...
        'TickDir','out');

    grid on;
    ax.GridLineStyle = '--';
    ax.GridAlpha = 0.24;

    all_lines = findobj(gca, 'Type', 'Line');
    set(all_lines, 'LineWidth', 1.4);

    h = findobj(gca, 'Tag', 'Box');
    for j = 1:length(h)
        patch(get(h(j),'XData'), get(h(j),'YData'), colors(length(h)-j+1,:), ...
            'FaceAlpha', 0.45, ...
            'EdgeColor', colors(length(h)-j+1,:), ...
            'LineWidth', 1.8);
    end

    med = findobj(gca, 'Tag', 'Median');
    set(med, 'Color', [0.85 0.10 0.10], 'LineWidth', 2.2);

    set(findobj(gca, 'Tag', 'Upper Whisker'), 'LineWidth', 1.6, 'Color', [0.20 0.20 0.20]);
    set(findobj(gca, 'Tag', 'Lower Whisker'), 'LineWidth', 1.6, 'Color', [0.20 0.20 0.20]);
    set(findobj(gca, 'Tag', 'Upper Adjacent Value'), 'LineWidth', 1.6, 'Color', [0.20 0.20 0.20]);
    set(findobj(gca, 'Tag', 'Lower Adjacent Value'), 'LineWidth', 1.6, 'Color', [0.20 0.20 0.20]);

    ylabel('Best Fitness Value', ...
        'FontName','Times New Roman', ...
        'FontSize',14, ...
        'FontWeight','bold');

    title(sprintf('Boxplot of Best Results on CEC2022-F%d', Function_name), ...
        'FontName','Times New Roman', ...
        'FontSize',16, ...
        'FontWeight','bold');

    box_png = fullfile(out_dir, sprintf('F%d_Boxplot.png', Function_name));
    box_pdf = fullfile(out_dir, sprintf('F%d_Boxplot.pdf', Function_name));
    saveas(gcf, box_png);
    saveas(gcf, box_pdf);
end