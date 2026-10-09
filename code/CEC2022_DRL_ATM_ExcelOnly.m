clc;
clear;
close all;

%% =========================================================
% 1. Basic settings
%% =========================================================
SearchAgents_no = 30;   % population size
dim = 10;               % CEC2022: only 2, 10, 20 are supported
Max_iteration = 500;    % iterations
lb = -100;              % lower bound
ub = 100;               % upper bound
runs = 20;              % number of independent runs

fhd = str2func('cec22_func');

% ===== ablation models: run DRL-SSA and ATM-SSA only =====
alg_names_plot = {'DRL-SSA', 'ATM-SSA'};
alg_names_var  = {'DRL_SSA', 'ATM_SSA'};
alg_num = numel(alg_names_plot);

%% =========================================================
% 2. Output folder
%% =========================================================
% Use a separate folder so the original F1-F12 Excel files are not overwritten.
out_dir = fullfile(pwd, 'CEC2022_DRL_ATM_F1_to_F12_ExcelOnly');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% =========================================================
% 3. Run F1-F12
%% =========================================================
for Function_name = 1:12

    fprintf('\n========================================\n');
    fprintf('Running Function F%d\n', Function_name);
    fprintf('========================================\n');

    % result containers for current function
    best_results  = zeros(runs, alg_num);                 % final best score of each run
    curve_results = zeros(Max_iteration, runs, alg_num);  % convergence curve of each run

    for a = 1:alg_num
        fprintf('\n------------------------------\n');
        fprintf('Algorithm: %s\n', alg_names_plot{a});
        fprintf('Function : F%d\n', Function_name);
        fprintf('------------------------------\n');

        for r = 1:runs
            rng(r, 'twister');

            [Best_score, cg_curve] = run_one_algorithm( ...
                alg_names_plot{a}, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);

            cg_curve = normalize_curve(cg_curve, Max_iteration);

            best_results(r, a) = Best_score;
            curve_results(:, r, a) = cg_curve;

            fprintf('Run %02d | Best = %.10e\n', r, Best_score);
        end
    end

    %% =====================================================
    % 4. Compute mean iteration curve and final statistics
    %% =====================================================
    mean_curves = squeeze(mean(curve_results, 2));    % [Max_iteration × alg_num]
    mean_vals   = mean(best_results, 1)';             % final best mean across runs
    var_vals    = var(best_results, 0, 1)';           % final best variance across runs

    %% =====================================================
    % 5. Save Excel for current function
    %% =====================================================
    excel_file = fullfile(out_dir, sprintf('F%d_results.xlsx', Function_name));

    % ---------- Sheet 1: IterationMean ----------
    T_iter = table((1:Max_iteration)', 'VariableNames', {'Iteration'});
    for a = 1:alg_num
        T_iter.(alg_names_var{a}) = mean_curves(:, a);
    end
    writetable(T_iter, excel_file, 'Sheet', 'IterationMean');

    % ---------- Sheet 2: MeanVariance ----------
    T_stat = table(alg_names_plot', mean_vals, var_vals, ...
        'VariableNames', {'Algorithm', 'Mean', 'Variance'});
    writetable(T_stat, excel_file, 'Sheet', 'MeanVariance');

    fprintf('\nExcel saved to:\n%s\n', excel_file);
end

fprintf('\nAll 12 Excel files have been saved to:\n%s\n', out_dir);

%% =========================================================
% Local function 1: run one algorithm
%% =========================================================
function [Best_score, cg_curve] = run_one_algorithm(alg_name, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name)

    % Classical algorithms use single-input objective
    fobj = @(x) fhd(x(:), Function_name);

    switch alg_name
        % ---------- ablation variants ----------
        case 'DRL-SSA'
            algo_handle = resolve_algorithm_handle({'DRL_SSA'});
            [Best_score, cg_curve] = call_hybrid_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name);

        case 'ATM-SSA'
            algo_handle = resolve_algorithm_handle({'ATM_SSA'});
            [Best_score, cg_curve] = call_hybrid_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name);

        % ---------- classical style ----------
        case 'PSO'
            algo_handle = resolve_algorithm_handle({'PSO'});
            [Best_score, cg_curve] = call_classic_algorithm( ...
                algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name);

        case 'GWO'
            algo_handle = resolve_algorithm_handle({'GWO','GWO2'});
            [Best_score, cg_curve] = call_classic_algorithm( ...
                algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name);

        case 'SSA'
            algo_handle = resolve_algorithm_handle({'SSA'});
            [Best_score, cg_curve] = call_classic_algorithm( ...
                algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name);

        % ---------- CEC-style / custom style ----------
        case 'AOO'
            algo_handle = resolve_algorithm_handle({'AOOv4','AOO'});
            [Best_score, cg_curve] = call_cecstyle_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name);

        case 'EM-SSA'
            algo_handle = resolve_algorithm_handle({'EM_SSA','EMSSA','EM_SSA_v1'});
            [Best_score, cg_curve] = call_cecstyle_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name);

        case 'AEM-SSA'
            algo_handle = resolve_algorithm_handle({'AEM_SSA','AEMSSA'});
            [Best_score, cg_curve] = call_cecstyle_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name);

        case 'ADR-SSA'
            algo_handle = resolve_algorithm_handle({'ADR_SSA','ARD_SSA','ADRSSA','ARDSSA'});
            [Best_score, cg_curve] = call_hybrid_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name);

        otherwise
            error('Unknown algorithm: %s', alg_name);
    end
end

%% =========================================================
% Local function 2: resolve handle by available file names
%% =========================================================
function algo_handle = resolve_algorithm_handle(name_candidates)
    for k = 1:numel(name_candidates)
        if exist(name_candidates{k}, 'file') == 2 || exist(name_candidates{k}, 'file') == 6
            algo_handle = str2func(name_candidates{k});
            return;
        end
    end
    error('None of these algorithm files were found: %s', strjoin(name_candidates, ', '));
end

%% =========================================================
% Local function 3: classical algorithm caller
%% =========================================================
function [Best_score, cg_curve] = call_classic_algorithm(algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name)

    % ---- Try 6 outputs ----
    try
        [Best_score, ~, cg_curve, ~, ~, ~] = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    % ---- Try 3 outputs ----
    try
        [Best_score, ~, cg_curve] = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    % ---- Try 2 outputs ----
    try
        [Best_score, cg_curve] = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    % ---- Try 1 output only ----
    try
        out1 = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);

        if isscalar(out1)
            Best_score = out1;
            cg_curve = repmat(Best_score, Max_iteration, 1);
            warning('%s only returns one output. A flat pseudo convergence curve was generated.', alg_name);
            return;
        elseif isvector(out1)
            cg_curve = out1(:);
            Best_score = cg_curve(end);
            warning('%s returned one vector output. It was treated as a convergence curve.', alg_name);
            return;
        else
            error('%s returned one output, but its format is unsupported.', alg_name);
        end
    catch ME
        error(['Classical algorithm call failed: ', ME.message]);
    end
end

%% =========================================================
% Local function 4: CEC-style algorithm caller
%% =========================================================
function [Best_score, cg_curve] = call_cecstyle_algorithm(algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name)

    % ---- Try 6 outputs ----
    try
        [Best_score, ~, cg_curve, ~, ~, ~] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    % ---- Try 3 outputs ----
    try
        [Best_score, ~, cg_curve] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    % ---- Try 2 outputs ----
    try
        [Best_score, cg_curve] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    % ---- Try 1 output only ----
    try
        out1 = algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);

        if isscalar(out1)
            Best_score = out1;
            cg_curve = repmat(Best_score, Max_iteration, 1);
            warning('%s only returns one output. A flat pseudo convergence curve was generated.', alg_name);
            return;
        elseif isvector(out1)
            cg_curve = out1(:);
            Best_score = cg_curve(end);
            warning('%s returned one vector output. It was treated as a convergence curve.', alg_name);
            return;
        else
            error('%s returned one output, but its format is unsupported.', alg_name);
        end
    catch ME
        error(['CEC-style algorithm call failed: ', ME.message]);
    end
end

%% =========================================================
% Local function 5: hybrid caller for DRL-SSA and ATM-SSA
%% =========================================================
function [Best_score, cg_curve] = call_hybrid_algorithm(algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name, alg_name)

    fobj = @(x) fhd(x(:), Function_name);

    % ---- Try classical interface first ----
    try
        [Best_score, ~, cg_curve, ~, ~, ~] = ...
            algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, ~, cg_curve] = ...
            algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, cg_curve] = ...
            algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    % ---- Then try CEC-style interface ----
    try
        [Best_score, ~, cg_curve, ~, ~, ~] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, ~, cg_curve] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, cg_curve] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, Function_name);
        cg_curve = cg_curve(:);
        return;
    catch ME
        error(['Hybrid algorithm call failed for ', alg_name, ': ', ME.message]);
    end
end

%% =========================================================
% Local function 6: normalize curve
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

    % best-so-far curve
    cg_curve = cummin(cg_curve);
end
