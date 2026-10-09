# ADR-SSA: An Enhanced Sparrow Search Algorithm for Complex Optimization and Data-Driven Forecasting

Execution code for the manuscript *"ADR-SSA: An Enhanced Sparrow Search Algorithm for Complex
Optimization and Data-Driven Forecasting"*.

ADR-SSA extends the Sparrow Search Algorithm (SSA) with two coordinated mechanisms:

1. **Dynamic reverse learning (DRL)** — repositions the worst-performing individuals relative to the
   evolving search region, which restores population diversity when the swarm contracts.
2. **Adaptive t-distribution mutation (ATM)** — perturbs elite individuals with a perturbation scale
   that adapts during iteration, strengthening late-stage local exploitation.

The algorithm is evaluated on the CEC2022 benchmark, on CEC2017 functions at 30/50/100 dimensions,
on two constrained engineering design problems (pressure vessel design, welded beam design), and in
an ADR-SSA-optimized CatBoost framework for provincial carbon emission forecasting.

## Requirements

- MATLAB (tested with R2020a or later; `writetable`/`readtable` are used throughout).
- Statistics and Machine Learning Toolbox — `ranksum` (Wilcoxon rank-sum tests) and `random`
  (normal variates in `levy.m`).
- **Windows x64** for the bundled benchmark MEX file `code/cec22_func.mexw64`. On other platforms,
  rebuild the MEX from the official CEC2022 MATLAB source (see *External dependencies* below) or use
  the plain `.m` version and keep it on the MATLAB path.
- Microsoft Excel is not required, but generated `.xlsx` result files can be opened with it.

## Repository layout

| File | Purpose |
| --- | --- |
| `code/ADR_SSA.m` | Implementation of ADR-SSA (dynamic reverse learning + adaptive t-distribution mutation). The entry function is `ADR_SSA(N, Max_iter, lb, ub, dim, fobj, params)`; an optional `params` struct controls the leader/elite ratios, reverse-learning ratio, mutation ratio and the stagnation limit. |
| `code/Ablation.m` | CEC2022 comparison of SSA vs. ADR-SSA for a single benchmark function (configurable dimension, runs and function index). Writes best values, statistics, mean convergence curves and a Wilcoxon p-value matrix to `CEC2022_F<k>_SSA_Comparison/F<k>_SSA_comparison_results.xlsx`. |
| `code/CEC2022_DRL_ATM_ExcelOnly.m` | Component ablation on CEC2022: runs the DRL-only and ATM-only variants against the full algorithm and exports per-function results to Excel. |
| `code/engineering.m` | Constrained engineering design problems (welded beam, pressure vessel) with seven optimizers (PSO, GWO, SSA, AOO, EM-SSA, AEM-SSA, ADR-SSA), 30 independent runs, 30 000 function evaluations per run. Writes `WBDP_PVDP_PaperStyle/WBDP_results.xlsx` and `PVDP_results.xlsx`. |
| `code/plot_engineering.m` | Reads the engineering results above and draws the ADR-SSA convergence curves into `WBDP_PVDP_ADR_SSA_BestCurve/`. |
| `code/machine.m` | Draws the machine-learning iteration curves used in the forecasting section from an input workbook (see *Data availability*). Output goes to `机器学习迭代曲线图/`. |
| `code/main.m` | Plots the 2-D/10-D landscapes of CEC2022 functions F1-F12 for illustration. Requires the CEC2022 toolbox function `Plot_CEC2022`. |
| `code/Get_CEC2022_details.m` | Helper returning lower/upper bounds, dimension and objective handle for CEC2022 F1-F12. |
| `code/initialization.m` | Uniform random population initialization with scalar or vector bounds (utility used by several variants). |
| `code/levy.m` | Lévy flight generator, after Yang & Deb's multi-objective cuckoo search (utility for mutation variants). |
| `code/Dive_Explor_Exploit.m` | Population-diversity and exploration/exploitation analysis from a recorded search history of size `[SearchAgents_no*Max_iteration, dim]`; saves EPS/SVG figures. |
| `code/cec22_func.mexw64` | Compiled CEC2022 benchmark suite (Windows x64) used by every CEC2022 experiment. |

## Running the experiments

Place `code/` on the MATLAB path (or `cd` into it — all scripts write their outputs relative to the
current folder), then run the script that corresponds to the experiment of interest:

```matlab
% CEC2022: SSA vs. ADR-SSA on a chosen function
Ablation.m                 % edit Function_name, dim, runs, Max_iteration at the top of the file

% CEC2022: component ablation (DRL-only vs. ATM-only)
CEC2022_DRL_ATM_ExcelOnly.m

% Constrained engineering design problems, then their convergence plots
engineering.m
plot_engineering.m

% Forecasting section iteration curves (needs the input workbook, see below)
machine.m
```

Experiment settings are declared in the first section of each script (`SearchAgents_no`, `dim`,
`runs`, `Max_iteration`, and the function or problem index). CEC2022 supports `dim = 2, 10, 20`; the
manuscript reports the 20-dimensional setting, while the scripts ship with `dim = 10` as the default.
Every script fixes the random seed per run (`rng(r, 'twister')`), so results are reproducible.

Note that `code/ADR_SSA.m` declares the function as `OLNL_SSA` (the earlier name of the method). It is
called as `ADR_SSA(...)` everywhere, which MATLAB resolves from the file name, so no renaming is
required.

## External dependencies

The comparison and ablation scripts resolve the competing optimizers by file name on the MATLAB path
(`resolve_algorithm_handle`). The following files are **not** bundled here and must be added to the
path before running the corresponding experiments:

| Needed by | Function files |
| --- | --- |
| `Ablation.m`, `CEC2022_DRL_ATM_ExcelOnly.m`, `engineering.m` | `SSA.m` (original sparrow search algorithm) |
| `CEC2022_DRL_ATM_ExcelOnly.m` | `DRL_SSA.m`, `ATM_SSA.m` (single-mechanism variants) |
| `engineering.m` | `PSO.m`, `GWO.m`, `AOO.m`, `EM_SSA.m`, `AEM_SSA.m` |
| `main.m` | `Plot_CEC2022.m` |
| CEC2022 experiments on non-Windows platforms | `cec22_func.m` and its input data, from the official CEC2022 MATLAB source released with the IEEE CEC 2022 competition |

Each algorithm file should expose the standard signature
`[Best_score, Best_pos, cg_curve] = algo(SearchAgents_no, Max_iteration, lb, ub, dim, fobj)`; the
caller also tolerates other output arities.

## Data availability

- The CEC2022 and CEC2017 benchmark suites are public and are not redistributed here beyond the
  compiled `cec22_func.mexw64`; download the official sources to rebuild or to use the suites.
- `machine.m` expects an input workbook named `迭代曲线(机器学习).xlsx` (sheets holding the
  per-iteration records of the compared model/optimizer combinations) in the current folder. The
  workbook and the CatBoost experiment scripts behind the provincial carbon emission forecasting
  results are not included in this repository.
- Provincial carbon emission and explanatory-variable data used in the forecasting section come from
  public statistical yearbooks and are described in the manuscript.

## Citation

If you use this code, please cite the manuscript:

> Li, C., Wang, J., Chen, Z., Qiu, X., Zhang, Y., & Wang, Y. *ADR-SSA: An Enhanced Sparrow Search
> Algorithm for Complex Optimization and Data-Driven Forecasting.*

## Contact

Corresponding author: Yile Wang — 2401050128@st.btbu.edu.cn
