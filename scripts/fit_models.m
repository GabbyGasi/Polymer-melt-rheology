% fit_models.m
% Graph 2: Fitting viscosity models to the full flow curve of polypropylene (Sample B, 190 C)
%
% Models (eta = viscosity, g = shear rate):
%   Power law:  eta = K * g^(n-1)                            (fitted for g >= 50 1/s only)
%   Cross:      eta = eta0 / (1 + (lambda*g)^(1-n))
%   Carreau:    eta = eta0 * (1 + (lambda*g)^2)^((n-1)/2)
%
% The fits minimize the squared difference between log10(model) and
% log10(data), because the viscosity spans almost three orders of magnitude.
% fminsearch is part of base MATLAB, so no extra toolbox is needed.
%
% Data: data/processed/sampleB_flowcurve_190C.csv
%       (NETZSCH AN 297, Figure 5, digitized with WebPlotDigitizer)

clear; close all;

%% 1. Folders
scriptDir  = fileparts(mfilename('fullpath'));
projectDir = fileparts(scriptDir);
dataFile   = fullfile(projectDir, 'data', 'processed', 'sampleB_flowcurve_190C.csv');
figDir     = fullfile(projectDir, 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

%% 2. Load the data
B     = readtable(dataFile);
g     = B.shear_rate_1_per_s;
eta   = B.viscosity_Pa_s;
isCap = strcmp(B.method, 'capillary');

%% 3. Fit the models
% Parameters are stored as p = [log10(eta0), log10(lambda), n] so that
% eta0 and lambda always stay positive during the search.
crossFun   = @(p, g) 10^p(1) ./ (1 + (10^p(2) * g).^(1 - p(3)));
carreauFun = @(p, g) 10^p(1) .* (1 + (10^p(2) * g).^2).^((p(3) - 1) / 2);

opts   = optimset('TolX', 1e-8, 'TolFun', 1e-10, 'MaxIter', 5000, 'MaxFunEvals', 10000);
pStart = [log10(4500), 0, 0.3];    % starting guess: eta0 = 4500 Pa.s, lambda = 1 s, n = 0.3

pCross   = fminsearch(@(p) sum((log10(crossFun(p, g))   - log10(eta)).^2), pStart, opts);
pCarreau = fminsearch(@(p) sum((log10(carreauFun(p, g)) - log10(eta)).^2), pStart, opts);

% Power law: straight line on a log-log plot, only in the shear-thinning region
plRange = g >= 50;
c    = polyfit(log10(g(plRange)), log10(eta(plRange)), 1);
nPL  = c(1) + 1;
K    = 10^c(2);
plFun = @(g) K * g.^(nPL - 1);

%% 4. How good is each fit?
% Typical error = root-mean-square of the log10 difference, converted to percent
typErr = @(model, data) (10^sqrt(mean((log10(model) - log10(data)).^2)) - 1) * 100;

errCross   = typErr(crossFun(pCross, g), eta);
errCarreau = typErr(carreauFun(pCarreau, g), eta);
errPL      = typErr(plFun(g(plRange)), eta(plRange));

fits = table(["Power law"; "Cross"; "Carreau"], ...
    [NaN; round(10^pCross(1)); round(10^pCarreau(1))], ...
    [NaN; round(10^pCross(2), 4); round(10^pCarreau(2), 4)], ...
    round([nPL; pCross(3); pCarreau(3)], 3), ...
    [round(K); NaN; NaN], ...
    round([errPL; errCross; errCarreau], 1), ...
    'VariableNames', {'model', 'eta0_Pa_s', 'lambda_s', 'n', 'K_Pa_s_n', 'typical_error_percent'});
disp(fits);
disp('(The power law is fitted only for shear rates >= 50 1/s.)');
writetable(fits, fullfile(projectDir, 'data', 'processed', 'sampleB_model_fits.csv'));

%% 5. Figure
fig = figure('Color', 'w', 'Position', [100 100 1250 480]);
try
    theme(fig, 'light');   % keep a white background even if MATLAB is in dark mode
catch
end
tl = tiledlayout(1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

orange = [0.85 0.33 0.10];
blue   = [0.00 0.45 0.74];
purple = [0.49 0.18 0.56];
green  = [0.47 0.67 0.19];
grey   = [0.90 0.90 0.90];

gFine = logspace(-3, 5, 300)';

% --- (a) Data and model curves
nexttile
hold on
% Shaded band: typical shear rates in extrusion (about 100-1000 1/s)
patch([1e2 1e3 1e3 1e2], [5 5 1e4 1e4], grey, 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(1.2e2, 7, 'typical extrusion', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);

plot(g(~isCap), eta(~isCap), 'o', 'Color', orange, 'MarkerFaceColor', orange, 'MarkerSize', 5);
plot(g(isCap),  eta(isCap),  's', 'Color', blue,   'MarkerFaceColor', blue,   'MarkerSize', 6);
plot(gFine, crossFun(pCross, gFine),     '-',  'Color', 'k',    'LineWidth', 1.8);
plot(gFine, carreauFun(pCarreau, gFine), '--', 'Color', purple, 'LineWidth', 1.8);
gPL = logspace(0, 5, 100)';
plot(gPL, plFun(gPL), ':', 'Color', green, 'LineWidth', 2.2);
hold off
set(gca, 'XScale', 'log', 'YScale', 'log', 'Layer', 'top');
grid on
xlim([1e-3 1e5]);  ylim([5 1e4]);
xlabel('Shear rate (1/s)');
ylabel('Viscosity (Pa\cdots)');
title('(a) Data and fitted models');
legend({'Rotational rheometer', 'Capillary rheometer', ...
        sprintf('Cross (n = %.2f)', pCross(3)), ...
        sprintf('Carreau (n = %.2f)', pCarreau(3)), ...
        sprintf('Power law (n = %.2f)', nPL)}, 'Location', 'southwest');

% --- (b) Residuals: how far each model is from each data point
nexttile
hold on
plot(g, (crossFun(pCross, g) ./ eta - 1) * 100, 'o-', 'Color', 'k', ...
     'MarkerFaceColor', 'k', 'MarkerSize', 4, 'LineWidth', 1);
plot(g, (carreauFun(pCarreau, g) ./ eta - 1) * 100, 's--', 'Color', purple, ...
     'MarkerFaceColor', purple, 'MarkerSize', 4, 'LineWidth', 1);
plot(g(plRange), (plFun(g(plRange)) ./ eta(plRange) - 1) * 100, '^:', 'Color', green, ...
     'MarkerFaceColor', green, 'MarkerSize', 5, 'LineWidth', 1.5);
yline(0, 'k-', 'HandleVisibility', 'off');
hold off
set(gca, 'XScale', 'log');
grid on
xlim([1e-3 1e5]);  ylim([-40 40]);
xlabel('Shear rate (1/s)');
ylabel('Model error (%)');
title('(b) Difference between model and data');
legend({sprintf('Cross (typical error %.0f%%)', errCross), ...
        sprintf('Carreau (typical error %.0f%%)', errCarreau), ...
        sprintf('Power law (typical error %.0f%%)', errPL)}, 'Location', 'southwest');

title(tl, sprintf('Polypropylene (Sample B) at 190 %sC: viscosity model fits', char(176)), ...
      'FontWeight', 'bold');

%% 6. Save
outFile = fullfile(figDir, 'model_fits.png');
exportgraphics(fig, outFile, 'Resolution', 300);
disp(['Saved: ' outFile]);
