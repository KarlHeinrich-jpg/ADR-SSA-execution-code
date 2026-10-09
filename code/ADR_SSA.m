function [BestScore, BestPos, Convergence_curve] = OLNL_SSA(N, Max_iter, lb, ub, dim, fobj, params)
% OLNL_SSA
% Rewritten big-improvement SSA with:
% 1) DynamicReverselearn strategy
% 2) Adaptive t-distribution perturbation mutation
%
% Input:
%   N, Max_iter, lb, ub, dim, fobj
%   params (optional struct):
%       .leader_frac   leader ratio, default 0.5
%       .elite_frac    elite ratio, default 0.2
%       .reverse_frac  worst-agent reverse learning ratio, default 0.3
%       .mutate_frac   elite mutation ratio, default 0.2
%       .stall_limit   stagnation threshold, default max(8, round(0.08*Max_iter))
%
% Output:
%   BestScore
%   BestPos
%   Convergence_curve

%% =========================================================
% 0. Parameters
%% =========================================================
if nargin < 7
    params = struct();
end

leader_frac  = getdef(params, 'leader_frac', 0.5);
elite_frac   = getdef(params, 'elite_frac', 0.2);
reverse_frac = getdef(params, 'reverse_frac', 0.3);
mutate_frac  = getdef(params, 'mutate_frac', 0.2);
stall_limit  = getdef(params, 'stall_limit', max(8, round(0.08 * Max_iter)));

%% =========================================================
% 1. Normalize bounds
%% =========================================================
if isscalar(lb), lb = lb .* ones(1, dim); end
if isscalar(ub), ub = ub .* ones(1, dim); end

lb = reshape(lb, 1, []);
ub = reshape(ub, 1, []);

if numel(lb) ~= dim || numel(ub) ~= dim
    error('The length of lb and ub must be 1 or equal to dim.');
end

range = ub - lb;

%% =========================================================
% 2. Initialize population
%% =========================================================
X = initialization(N, dim, ub, lb);
fit = evaluate_population(X, fobj);

[BestScore, idx] = min(fit);
BestPos = X(idx, :);

Convergence_curve = zeros(1, Max_iter);

n_leader = max(1, ceil(leader_frac * N));
n_elite  = max(2, ceil(elite_frac * N));
n_reverse = max(1, ceil(reverse_frac * N));
n_mutate  = max(1, ceil(mutate_frac * N));

no_improve = 0;

%% =========================================================
% 3. Main loop
%% =========================================================
for t = 1:Max_iter

    prevBest = BestScore;

    % ---------- Sort population ----------
    [fit, idx_sort] = sort(fit, 'ascend');
    X = X(idx_sort, :);

    if fit(1) < BestScore
        BestScore = fit(1);
        BestPos = X(1, :);
    end

    Elite_X = X(1:n_elite, :);
    Elite_mean = mean(Elite_X, 1);

    %% =====================================================
    % Step A: Standard SSA position update
    %% =====================================================
    % Nonlinear c1 (keep SSA flavor, but smoother)
    tau = t / Max_iter;
    c1 = 2 * exp(-(4 * tau)^2);

    Xnew = X;

    % ---------- Leaders ----------
    for i = 1:n_leader
        for j = 1:dim
            c2 = rand();
            c3 = rand();

            step = c1 * range(j) * c2;

            if c3 >= 0.5
                Xnew(i, j) = BestPos(j) + step;
            else
                Xnew(i, j) = BestPos(j) - step;
            end
        end

        % add elite guidance to strengthen real difference from original SSA
        guide_weight = 0.25 * (1 - tau);
        Xnew(i, :) = (1 - guide_weight) * Xnew(i, :) + guide_weight * Elite_mean;
    end

    % ---------- Followers ----------
    for i = n_leader+1:N
        % keep chain update, but add weak attraction to best
        X_chain = (Xnew(i-1, :) + X(i, :)) / 2;
        X_best_pull = X_chain + 0.08 * (1 - tau) * rand(1, dim) .* (BestPos - X(i, :));
        Xnew(i, :) = X_best_pull;
    end

    % ---------- Boundary ----------
    Xnew = min(max(Xnew, lb), ub);

    % ---------- Greedy selection ----------
    fit_new = evaluate_population(Xnew, fobj);
    improve = fit_new < fit;
    X(improve, :) = Xnew(improve, :);
    fit(improve) = fit_new(improve);

    [curBest, curIdx] = min(fit);
    if curBest < BestScore
        BestScore = curBest;
        BestPos = X(curIdx, :);
    end

    %% =====================================================
    % Step B: DynamicReverselearn strategy
    %% =====================================================
    [fit, idx_sort] = sort(fit, 'ascend');
    X = X(idx_sort, :);

    dynamic_lb = min(X, [], 1);
    dynamic_ub = max(X, [], 1);

    Elite_X = X(1:n_elite, :);
    Elite_mean = mean(Elite_X, 1);
    center = 0.5 * (BestPos + Elite_mean);

    % select worst agents
    reverse_idx = N-n_reverse+1 : N;

    eta = 1 - tau;   % stronger reverse learning in early-mid stage

    for kk = 1:numel(reverse_idx)
        i = reverse_idx(kk);

        % reverse around dynamic population bounds
        Xopp1 = dynamic_lb + dynamic_ub - X(i, :);

        % reverse around dynamic center
        Xopp2 = 2 * center - X(i, :);

        % dynamic combination
        Xrev = eta * Xopp1 + (1 - eta) * Xopp2;

        % contraction toward center for stability
        rr = rand(1, dim);
        Xrev = center + rr .* (Xrev - center);

        Xrev = min(max(Xrev, lb), ub);
        f_rev = fobj(Xrev);

        if f_rev < fit(i)
            X(i, :) = Xrev;
            fit(i) = f_rev;
        end

        if f_rev < BestScore
            BestScore = f_rev;
            BestPos = Xrev;
        end
    end

    %% =====================================================
    % Step C: Adaptive t-distribution perturbation mutation
    %% =====================================================
    [fit, idx_sort] = sort(fit, 'ascend');
    X = X(idx_sort, :);

    % adaptive degree of freedom:
    % early stage -> small df -> heavy tail
    % late stage  -> large df -> close to Gaussian
    nu = max(1, round(1 + 30 * tau));

    % mutation scale: stronger early, finer late
    sigma = 0.12 * (1 - tau) + 0.01;

    mutate_idx = 1:n_mutate;

    for kk = 1:numel(mutate_idx)
        i = mutate_idx(kk);

        t_noise = student_t_rand(nu, 1, dim);

        % mutate around current elite individual
        Xmut = X(i, :) + sigma .* range .* t_noise;

        % extra best guidance
        Xmut = 0.7 * Xmut + 0.3 * BestPos;

        Xmut = min(max(Xmut, lb), ub);
        f_mut = fobj(Xmut);

        if f_mut < fit(i)
            X(i, :) = Xmut;
            fit(i) = f_mut;
        end

        if f_mut < BestScore
            BestScore = f_mut;
            BestPos = Xmut;
        end
    end

    %% =====================================================
    % Step D: Strong mutation under stagnation
    %% =====================================================
    if BestScore < prevBest
        no_improve = 0;
    else
        no_improve = no_improve + 1;
    end

    if no_improve >= stall_limit
        % stronger adaptive t mutation around best
        nu2 = max(1, round(2 + 10 * tau));
        sigma2 = 0.18 * (1 - tau) + 0.03;

        for kk = 1:max(2, n_mutate)
            t_noise2 = student_t_rand(nu2, 1, dim);
            Xtrial = BestPos + sigma2 .* range .* t_noise2;
            Xtrial = min(max(Xtrial, lb), ub);

            f_trial = fobj(Xtrial);

            if f_trial < BestScore
                BestScore = f_trial;
                BestPos = Xtrial;
            end
        end

        no_improve = 0;
    end

    %% =====================================================
    % Step E: Record convergence
    %% =====================================================
    Convergence_curve(t) = BestScore;
end

Convergence_curve = cummin(Convergence_curve);

end

%% =========================================================
% Subfunctions
%% =========================================================

function X = initialization(SearchAgents_no, dim, ub, lb)
X = zeros(SearchAgents_no, dim);
for i = 1:dim
    X(:, i) = rand(SearchAgents_no, 1) .* (ub(i) - lb(i)) + lb(i);
end
end

function fit = evaluate_population(X, fobj)
N = size(X, 1);
fit = zeros(N, 1);
for i = 1:N
    fit(i) = fobj(X(i, :));
end
end

function r = student_t_rand(df, m, n)
% Generate Student-t random variables without Statistics Toolbox
% df should be positive integer here
if df < 1
    df = 1;
end
Z = randn(m, n);
V = zeros(m, n);
for k = 1:df
    V = V + randn(m, n).^2;
end
r = Z ./ sqrt(V / df);
end

function v = getdef(s, f, d)
if isfield(s, f)
    v = s.(f);
else
    v = d;
end
end