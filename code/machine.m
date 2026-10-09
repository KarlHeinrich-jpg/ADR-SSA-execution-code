clc;
clear;
close all;

%% =========================================================
% 1. Basic settings
%% =========================================================
FONT_NAME = 'Times New Roman';

% 当前文件夹中的 Excel 文件
excel_file = fullfile(pwd, '迭代曲线(机器学习).xlsx');

if ~exist(excel_file, 'file')
    error('文件不存在：%s', excel_file);
end

% 输出文件夹
out_dir = fullfile(pwd, '机器学习迭代曲线图');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% =========================================================
% 2. Detect sheet name
%% =========================================================
sheet_names = sheetnames(excel_file);

% 优先使用这些常见 sheet 名
preferred_sheets = {'Curves_Mean', 'IterationMean', 'Sheet1'};
sheet_to_read = '';

for i = 1:numel(preferred_sheets)
    if any(strcmp(sheet_names, preferred_sheets{i}))
        sheet_to_read = preferred_sheets{i};
        break;
    end
end

% 如果都没有，就默认第一个 sheet
if isempty(sheet_to_read)
    sheet_to_read = sheet_names{1};
end

fprintf('读取文件: %s\n', excel_file);
fprintf('读取工作表: %s\n', sheet_to_read);

%% =========================================================
% 3. Read data
%% =========================================================
T = readtable(excel_file, 'Sheet', sheet_to_read, 'VariableNamingRule', 'preserve');

if isempty(T)
    error('读取到的表为空。');
end

varNames = T.Properties.VariableNames;

% 自动识别迭代列
iterCandidates = {'Iteration', 'iteration', 'Iter', 'iter'};
iter_col = '';

for i = 1:numel(iterCandidates)
    if any(strcmp(varNames, iterCandidates{i}))
        iter_col = iterCandidates{i};
        break;
    end
end

if isempty(iter_col)
    % 默认第一列为迭代列
    iter_col = varNames{1};
    warning('未找到名为 Iteration 的列，默认使用第一列 "%s" 作为横轴。', iter_col);
end

iterations = T.(iter_col);
iterations = iterations(:);

% 其余列视为模型曲线
curve_cols = setdiff(varNames, {iter_col}, 'stable');

if isempty(curve_cols)
    error('除迭代列外，没有找到任何模型曲线列。');
end

% 构建曲线矩阵
alg_num = numel(curve_cols);
mean_curves = zeros(numel(iterations), alg_num);

for a = 1:alg_num
    mean_curves(:, a) = T.(curve_cols{a});
end

% 显示名称：把下划线替换为连字符，更好看一点
alg_names_plot = curve_cols;
for a = 1:numel(alg_names_plot)
    alg_names_plot{a} = strrep(alg_names_plot{a}, '_', '-');
end

%% =========================================================
% 4. Style settings
%% =========================================================
% 如果模型数量超过默认颜色数，会自动循环
base_colors = [
    31 119 180;   % PSO
    127 127 127;  % GWO
    23 190 207;   % SSA
    255 127 14;   % AOO
    44 160 44;    % EM-SSA
    148 103 189;  % AEM-SSA
    214 39 40     % ADR-SSA
] / 255;

line_styles_pool = {':','-.','--',':','-.','--','-'};
markers_pool = {'o','p','v','^','d','s','o'};

colors = zeros(alg_num, 3);
line_styles = cell(1, alg_num);
markers = cell(1, alg_num);

for a = 1:alg_num
    idx = mod(a-1, size(base_colors, 1)) + 1;
    colors(a, :) = base_colors(idx, :);
    line_styles{a} = line_styles_pool{mod(a-1, numel(line_styles_pool)) + 1};
    markers{a} = markers_pool{mod(a-1, numel(markers_pool)) + 1};
end

%% =========================================================
% 5. Plot adaptive convergence curve
%% =========================================================
fig = figure('Color', 'w', 'Position', [100, 100, 1080, 620]);
ax = axes;
hold(ax, 'on');

marker_idx = round(linspace(1, numel(iterations), min(12, numel(iterations))));

% 自适应纵轴
[use_log_curve, ymin_curve, ymax_curve, eps_floor_curve] = adaptive_axis_info(mean_curves);

h = gobjects(alg_num, 1);
for a = 1:alg_num
    y = mean_curves(:, a);
    y = y(:);

    if use_log_curve
        y_plot = y;
        y_plot(~isfinite(y_plot) | y_plot <= 0) = eps_floor_curve;

        h(a) = plot(iterations, y_plot, ...
            'LineWidth', 3.0, ...
            'LineStyle', line_styles{a}, ...
            'Color', colors(a,:), ...
            'Marker', markers{a}, ...
            'MarkerIndices', marker_idx, ...
            'MarkerSize', 6.0, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', colors(a,:));
    else
        h(a) = plot(iterations, y, ...
            'LineWidth', 3.0, ...
            'LineStyle', line_styles{a}, ...
            'Color', colors(a,:), ...
            'Marker', markers{a}, ...
            'MarkerIndices', marker_idx, ...
            'MarkerSize', 6.0, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', colors(a,:));
    end
end

set(ax, ...
    'FontName', FONT_NAME, ...
    'FontSize', 18, ...
    'LineWidth', 1.8, ...
    'Box', 'on', ...
    'TickDir', 'out', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off');

xlabel('Iteration', ...
    'FontName', FONT_NAME, ...
    'FontSize', 20, ...
    'FontWeight', 'bold');

ylabel('Fitness (NRMSE)', ...
    'FontName', FONT_NAME, ...
    'FontSize', 20, ...
    'FontWeight', 'bold');

title('Convergence Curve', ...
    'FontName', FONT_NAME, ...
    'FontSize', 20, ...
    'FontWeight', 'bold');

legend(h, alg_names_plot, ...
    'Location', 'northeast', ...
    'FontName', FONT_NAME, ...
    'FontSize', 14, ...
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

grid(ax, 'off');

%% =========================================================
% 6. Save figure
%% =========================================================
png_file = fullfile(out_dir, 'ConvergenceCurve_ML_Fitness_NRMSE.png');
pdf_file = fullfile(out_dir, 'ConvergenceCurve_ML_Fitness_NRMSE.pdf');

exportgraphics(fig, png_file, 'Resolution', 400);
exportgraphics(fig, pdf_file, 'ContentType', 'vector');

fprintf('\n图像已保存到：\n%s\n%s\n', png_file, pdf_file);

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