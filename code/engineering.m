clc;
clear;
close all;

%% =========================================================
% 1. Basic settings
%% =========================================================
SearchAgents_no = 30;     % population size
runs            = 30;     % independent runs
maxFEs          = 30000;  % same spirit as paper's comparison setting
Max_iteration   = floor(maxFEs / SearchAgents_no);   % 1000

% ===== comparison models =====
alg_names_plot = {'PSO', 'GWO', 'SSA', 'AOO', 'EM-SSA', 'AEM-SSA', 'ADR-SSA'};
alg_names_var  = {'PSO', 'GWO', 'SSA', 'AOO', 'EM_SSA', 'AEM_SSA', 'ADR_SSA'};
alg_num = numel(alg_names_plot);

% ===== constrained problems =====
problem_names = {'WBDP', 'PVDP'};

%% =========================================================
% 2. Output folder
%% =========================================================
out_dir = fullfile(pwd, 'WBDP_PVDP_PaperStyle');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% =========================================================
% 3. Run WBDP and PVDP
%% =========================================================
for p = 1:numel(problem_names)

    problem_name = problem_names{p};
    [lb, ub, dim] = get_problem_info(problem_name);

    fprintf('\n========================================\n');
    fprintf('Running Problem: %s\n', problem_name);
    fprintf('pop = %d | runs = %d | maxFEs = %d | iter = %d\n', ...
        SearchAgents_no, runs, maxFEs, Max_iteration);
    fprintf('========================================\n');

    % result containers
    raw_results       = nan(runs, alg_num);
    penalized_results = nan(runs, alg_num);
    violation_results = nan(runs, alg_num);
    feasible_results  = nan(runs, alg_num);
    best_positions    = nan(runs, alg_num, dim);
    curve_results     = nan(Max_iteration, runs, alg_num);

    for a = 1:alg_num
        fprintf('\n------------------------------\n');
        fprintf('Algorithm: %s\n', alg_names_plot{a});
        fprintf('Problem  : %s\n', problem_name);
        fprintf('------------------------------\n');

        for r = 1:runs
            rng(r, 'twister');

            [Best_score, Best_pos, cg_curve] = run_one_algorithm( ...
                alg_names_plot{a}, problem_name, dim, SearchAgents_no, Max_iteration, lb, ub);

            cg_curve = normalize_curve(cg_curve, Max_iteration);

            if ~isempty(Best_pos) && all(isfinite(Best_pos))
                Best_pos = postprocess_solution(Best_pos, problem_name);
                [raw_obj, total_violation, is_feasible] = evaluate_solution(Best_pos, problem_name);
                best_positions(r, a, :) = Best_pos(:);
            else
                raw_obj = NaN;
                total_violation = NaN;
                is_feasible = NaN;
            end

            raw_results(r, a)       = raw_obj;
            penalized_results(r, a) = Best_score;
            violation_results(r, a) = total_violation;
            feasible_results(r, a)  = is_feasible;
            curve_results(:, r, a)  = cg_curve;

            fprintf('Run %02d | Penalized = %.10e | RawObj = %.10e | Viol = %.4e | Feasible = %d\n', ...
                r, Best_score, raw_obj, total_violation, round_nan(is_feasible));
        end
    end

    %% =====================================================
    % 4. Statistics and best-run selection
    %% =====================================================
    mean_curves = squeeze(mean(curve_results, 2, 'omitnan'));

    stat_algorithm = cell(alg_num, 1);
    stat_best      = nan(alg_num, 1);
    stat_mean      = nan(alg_num, 1);
    stat_std       = nan(alg_num, 1);
    stat_worst     = nan(alg_num, 1);
    stat_feas_rate = nan(alg_num, 1);
    stat_best_run  = nan(alg_num, 1);

    best_decision_vars = nan(alg_num, dim);
    best_run_curve     = nan(Max_iteration, alg_num);

    for a = 1:alg_num
        raw_col  = raw_results(:, a);
        pen_col  = penalized_results(:, a);
        vio_col  = violation_results(:, a);
        feas_col = feasible_results(:, a);

        stat_algorithm{a} = alg_names_plot{a};
        stat_best(a)      = min(raw_col, [], 'omitnan');
        stat_mean(a)      = mean(raw_col, 'omitnan');
        stat_std(a)       = std(raw_col, 0, 'omitnan');
        stat_worst(a)     = max(raw_col, [], 'omitnan');
        stat_feas_rate(a) = 100 * mean(feas_col, 'omitnan');

        best_idx = select_best_run(raw_col, pen_col, vio_col, feas_col);
        stat_best_run(a) = best_idx;

        if ~isnan(best_idx)
            best_decision_vars(a, :) = squeeze(best_positions(best_idx, a, :))';
            best_run_curve(:, a)     = curve_results(:, best_idx, a);
        end
    end

    % ranking by unrounded Best
    [~, order_best] = sort(stat_best, 'ascend');
    ranks = zeros(alg_num, 1);
    ranks(order_best) = 1:alg_num;

    %% =====================================================
    % 5. Save Excel
    %% =====================================================
    excel_file = fullfile(out_dir, sprintf('%s_results.xlsx', problem_name));

    % ---------- Sheet 1: AllRuns ----------
    all_algorithms = {};
    all_runs = [];
    all_raw = [];
    all_pen = [];
    all_viol = [];
    all_feas = [];
    all_x = [];

    for a = 1:alg_num
        for r = 1:runs
            all_algorithms{end+1,1} = alg_names_plot{a}; %#ok<AGROW>
            all_runs(end+1,1)       = r;                 %#ok<AGROW>
            all_raw(end+1,1)        = raw_results(r,a); %#ok<AGROW>
            all_pen(end+1,1)        = penalized_results(r,a); %#ok<AGROW>
            all_viol(end+1,1)       = violation_results(r,a); %#ok<AGROW>
            all_feas(end+1,1)       = feasible_results(r,a); %#ok<AGROW>
            all_x(end+1,:)          = squeeze(best_positions(r,a,:))'; %#ok<AGROW>
        end
    end

    T_all = table(all_algorithms, all_runs, all_raw, all_pen, all_viol, all_feas, ...
        'VariableNames', {'Algorithm', 'Run', 'RawObjective', 'PenalizedFitness', ...
                          'TotalViolation', 'Feasible'});
    for d = 1:dim
        T_all.(sprintf('x%d', d)) = all_x(:, d);
    end
    writetable(T_all, excel_file, 'Sheet', 'AllRuns');

    % ---------- Sheet 2: Statistics ----------
    T_stat = table(stat_algorithm, stat_best, stat_mean, stat_std, stat_worst, ...
        stat_feas_rate, ranks, stat_best_run, ...
        'VariableNames', {'Algorithm', 'Best', 'Mean', 'Std', 'Worst', ...
                          'FeasibleRate_percent', 'Rank', 'BestRun'});
    writetable(T_stat, excel_file, 'Sheet', 'Statistics');

    % ---------- Sheet 3: BestDecisionVariables ----------
    T_dec = table(stat_algorithm, stat_best_run, ...
        'VariableNames', {'Algorithm', 'BestRun'});
    for d = 1:dim
        T_dec.(sprintf('x%d', d)) = best_decision_vars(:, d);
    end
    writetable(T_dec, excel_file, 'Sheet', 'BestDecisionVariables');

    % ---------- Sheet 4: BestRunCurve ----------
    T_best_curve = table((1:Max_iteration)', 'VariableNames', {'Iteration'});
    for a = 1:alg_num
        T_best_curve.(alg_names_var{a}) = best_run_curve(:, a);
    end
    writetable(T_best_curve, excel_file, 'Sheet', 'BestRunCurve');

    % ---------- Sheet 5: MeanCurve ----------
    T_mean_curve = table((1:Max_iteration)', 'VariableNames', {'Iteration'});
    for a = 1:alg_num
        T_mean_curve.(alg_names_var{a}) = mean_curves(:, a);
    end
    writetable(T_mean_curve, excel_file, 'Sheet', 'MeanCurve');

    fprintf('\nExcel saved to:\n%s\n', excel_file);
end

fprintf('\nAll problem Excel files have been saved to:\n%s\n', out_dir);

%% =========================================================
% Local function 1: run one algorithm
%% =========================================================
function [Best_score, Best_pos, cg_curve] = run_one_algorithm(alg_name, problem_name, dim, SearchAgents_no, Max_iteration, lb, ub)

    fobj = @(x) constrained_problem_penalty(x, problem_name);
    fhd  = @constrained_problem_penalty;

    switch alg_name
        case 'PSO'
            algo_handle = resolve_algorithm_handle({'PSO'});
            [Best_score, Best_pos, cg_curve] = call_classic_algorithm( ...
                algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name);

        case 'GWO'
            algo_handle = resolve_algorithm_handle({'GWO','GWO2'});
            [Best_score, Best_pos, cg_curve] = call_classic_algorithm( ...
                algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name);

        case 'SSA'
            algo_handle = resolve_algorithm_handle({'SSA'});
            [Best_score, Best_pos, cg_curve] = call_classic_algorithm( ...
                algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name);

        case 'AOO'
            algo_handle = resolve_algorithm_handle({'AOOv4','AOO'});
            [Best_score, Best_pos, cg_curve] = call_cecstyle_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name, alg_name);

        case 'EM-SSA'
            algo_handle = resolve_algorithm_handle({'EM_SSA','EMSSA','EM_SSA_v1'});
            [Best_score, Best_pos, cg_curve] = call_cecstyle_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name, alg_name);

        case 'AEM-SSA'
            algo_handle = resolve_algorithm_handle({'AEM_SSA','AEMSSA'});
            [Best_score, Best_pos, cg_curve] = call_cecstyle_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name, alg_name);

        case 'ADR-SSA'
            algo_handle = resolve_algorithm_handle({'ADR_SSA','ARD_SSA','ADRSSA','ARDSSA'});
            [Best_score, Best_pos, cg_curve] = call_hybrid_algorithm( ...
                algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name, alg_name);

        otherwise
            error('Unknown algorithm: %s', alg_name);
    end
end

%% =========================================================
% Local function 2: resolve handle
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
function [Best_score, Best_pos, cg_curve] = call_classic_algorithm(algo_handle, SearchAgents_no, Max_iteration, lb, ub, dim, fobj, alg_name)

    Best_pos = [];
    cg_curve = [];

    try
        [Best_score, Best_pos, cg_curve, ~, ~, ~] = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, Best_pos, cg_curve] = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [out1, out2] = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        Best_score = out1;
        if isvector(out2) && numel(out2) == dim
            Best_pos = out2(:)';
            cg_curve = repmat(Best_score, Max_iteration, 1);
        else
            Best_pos = [];
            cg_curve = out2(:);
        end
        return;
    catch
    end

    try
        out1 = algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        if isscalar(out1)
            Best_score = out1;
            Best_pos = [];
            cg_curve = repmat(Best_score, Max_iteration, 1);
            warning('%s only returns one scalar output. A flat pseudo curve was generated.', alg_name);
            return;
        elseif isvector(out1)
            Best_score = out1(end);
            Best_pos = [];
            cg_curve = out1(:);
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
% Local function 4: cec-style algorithm caller
%% =========================================================
function [Best_score, Best_pos, cg_curve] = call_cecstyle_algorithm(algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name, alg_name)

    Best_pos = [];
    cg_curve = [];

    try
        [Best_score, Best_pos, cg_curve, ~, ~, ~] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, Best_pos, cg_curve] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [out1, out2] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name);
        Best_score = out1;
        if isvector(out2) && numel(out2) == dim
            Best_pos = out2(:)';
            cg_curve = repmat(Best_score, Max_iteration, 1);
        else
            Best_pos = [];
            cg_curve = out2(:);
        end
        return;
    catch
    end

    try
        out1 = algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name);
        if isscalar(out1)
            Best_score = out1;
            Best_pos = [];
            cg_curve = repmat(Best_score, Max_iteration, 1);
            warning('%s only returns one scalar output. A flat pseudo curve was generated.', alg_name);
            return;
        elseif isvector(out1)
            Best_score = out1(end);
            Best_pos = [];
            cg_curve = out1(:);
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
% Local function 5: hybrid caller
%% =========================================================
function [Best_score, Best_pos, cg_curve] = call_hybrid_algorithm(algo_handle, fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name, alg_name)

    Best_pos = [];
    cg_curve = [];
    fobj = @(x) constrained_problem_penalty(x, problem_name);

    try
        [Best_score, Best_pos, cg_curve, ~, ~, ~] = ...
            algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, Best_pos, cg_curve] = ...
            algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [out1, out2] = ...
            algo_handle(SearchAgents_no, Max_iteration, lb, ub, dim, fobj);
        Best_score = out1;
        if isvector(out2) && numel(out2) == dim
            Best_pos = out2(:)';
            cg_curve = repmat(Best_score, Max_iteration, 1);
        else
            Best_pos = [];
            cg_curve = out2(:);
        end
        return;
    catch
    end

    try
        [Best_score, Best_pos, cg_curve, ~, ~, ~] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [Best_score, Best_pos, cg_curve] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name);
        cg_curve = cg_curve(:);
        return;
    catch
    end

    try
        [out1, out2] = ...
            algo_handle(fhd, dim, SearchAgents_no, Max_iteration, lb, ub, problem_name);
        Best_score = out1;
        if isvector(out2) && numel(out2) == dim
            Best_pos = out2(:)';
            cg_curve = repmat(Best_score, Max_iteration, 1);
        else
            Best_pos = [];
            cg_curve = out2(:);
        end
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

    cg_curve = cummin(cg_curve);
end

%% =========================================================
% Local function 7: select best run
%% =========================================================
function best_idx = select_best_run(raw_col, pen_col, vio_col, feas_col)

    best_idx = NaN;

    feasible_idx = find(feas_col == 1);
    if ~isempty(feasible_idx)
        feasible_raw = raw_col(feasible_idx);
        [~, loc] = min(feasible_raw);
        best_idx = feasible_idx(loc);
        return;
    end

    valid_vio = ~isnan(vio_col);
    if any(valid_vio)
        min_vio = min(vio_col(valid_vio));
        cand = find(vio_col == min_vio);
        if numel(cand) == 1
            best_idx = cand;
        else
            [~, loc] = min(pen_col(cand));
            best_idx = cand(loc);
        end
        return;
    end

    valid_pen = ~isnan(pen_col);
    if any(valid_pen)
        [~, best_idx] = min(pen_col);
    end
end

%% =========================================================
% Local function 8: problem info
%% =========================================================
function [lb, ub, dim] = get_problem_info(problem_name)

    switch upper(problem_name)
        case 'WBDP'
            % x = [h, l, t, b]
            lb = [0.1, 0.1, 0.1, 0.1];
            ub = [2.0, 10.0, 10.0, 2.0];

        case 'PVDP'
            % x = [Ts, Th, R, L]  continuous version in this paper
            lb = [0.0, 0.0, 10.0, 10.0];
            ub = [99.0, 99.0, 200.0, 200.0];

        otherwise
            error('Unknown problem: %s', problem_name);
    end

    dim = numel(lb);
end

%% =========================================================
% Local function 9: penalty wrapper
%% =========================================================
function f_pen = constrained_problem_penalty(x, problem_name)

    x = x(:)';
    x = postprocess_solution(x, problem_name);

    [f_raw, g] = constrained_problem_details(x, problem_name);

    penalty_coeff = 1e10;
    violation = max(0, g);
    f_pen = f_raw + penalty_coeff * sum(violation.^2);
end

%% =========================================================
% Local function 10: evaluate final solution
%% =========================================================
function [f_raw, total_violation, is_feasible] = evaluate_solution(x, problem_name)

    x = x(:)';
    x = postprocess_solution(x, problem_name);

    [f_raw, g] = constrained_problem_details(x, problem_name);

    violation = max(0, g);
    total_violation = sum(violation);
    is_feasible = all(g <= 1e-8);
end

%% =========================================================
% Local function 11: postprocess solution
%% =========================================================
function x = postprocess_solution(x, problem_name)
    x = x(:)';

    switch upper(problem_name)
        case 'WBDP'
            % continuous
        case 'PVDP'
            % continuous in this paper, no discretization
        otherwise
            error('Unknown problem: %s', problem_name);
    end
end

%% =========================================================
% Local function 12: raw problem definitions
%% =========================================================
function [f, g] = constrained_problem_details(x, problem_name)

    switch upper(problem_name)
        case 'WBDP'
            [f, g] = welded_beam_problem(x);

        case 'PVDP'
            [f, g] = pressure_vessel_problem(x);

        otherwise
            error('Unknown problem: %s', problem_name);
    end
end

%% =========================================================
% Local function 13: Welded Beam Design Problem (WBDP)
%% =========================================================
function [f, g] = welded_beam_problem(x)
    % x = [h, l, t, b]
    x1 = x(1);
    x2 = x(2);
    x3 = x(3);
    x4 = x(4);

    P = 6000;
    L = 14;
    E = 30e6;
    G = 12e6;
    tau_max   = 13600;
    sigma_max = 30000;
    delta_max = 0.25;

    f = 1.10471 * x1^2 * x2 + 0.04811 * x3 * x4 * (14 + x2);

    M = P * (L + x2 / 2);
    R = sqrt(x2^2 / 4 + ((x1 + x3) / 2)^2);
    J = 2 * sqrt(2) * x1 * x2 * (x2^2 / 12 + ((x1 + x3) / 2)^2);

    tau1 = P / (sqrt(2) * x1 * x2);
    tau2 = M * R / J;
    tau  = sqrt(tau1^2 + 2 * tau1 * tau2 * x2 / (2 * R) + tau2^2);

    sigma = 6 * P * L / (x4 * x3^2);
    delta = 4 * P * L^3 / (E * x3^3 * x4);

    Pc = 4.013 * E * sqrt(x3^2 * x4^6 / 36) / L^2 * ...
        (1 - x3 / (2 * L) * sqrt(E / (4 * G)));

    % g(x) <= 0
    g = [
        tau - tau_max;
        sigma - sigma_max;
        x1 - x4;
        1.10471 * x1^2 + 0.04811 * x3 * x4 * (14 + x2) - 5;
        0.125 - x1;
        delta - delta_max;
        P - Pc
    ];
end

%% =========================================================
% Local function 14: Pressure Vessel Design Problem (PVDP)
%% =========================================================
function [f, g] = pressure_vessel_problem(x)
    % x = [Ts, Th, R, L]
    x1 = x(1);
    x2 = x(2);
    x3 = x(3);
    x4 = x(4);

    f = 0.6224 * x1 * x3 * x4 + ...
        1.7781 * x2 * x3^2 + ...
        3.1661 * x1^2 * x4 + ...
        19.84  * x1^2 * x3;

    % g(x) <= 0
    g = [
        -x1 + 0.0193 * x3;
        -x2 + 0.00954 * x3;
        -pi * x3^2 * x4 - (4/3) * pi * x3^3 + 1296000;
        x4 - 240
    ];
end

%% =========================================================
% Local function 15: safe round for display
%% =========================================================
function y = round_nan(x)
    if isnan(x)
        y = -1;
    else
        y = round(x);
    end
end