function X = initialization(SearchAgents_no, dim, ub, lb)
% initialization for population-based metaheuristics
% Supports scalar or vector bounds.

    if isscalar(ub)
        ub = ub * ones(1, dim);
    else
        ub = reshape(ub, 1, []);
    end

    if isscalar(lb)
        lb = lb * ones(1, dim);
    else
        lb = reshape(lb, 1, []);
    end

    if numel(ub) ~= dim || numel(lb) ~= dim
        error('The length of lb and ub must be 1 or equal to dim.');
    end

    X = zeros(SearchAgents_no, dim);
    for i = 1:dim
        X(:, i) = rand(SearchAgents_no, 1) .* (ub(i) - lb(i)) + lb(i);
    end
end