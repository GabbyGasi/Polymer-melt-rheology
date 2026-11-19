% die_pressure.m
% Graph 3: How much pressure is needed to push polypropylene through an extrusion die?
%
% Die: circular strand die, diameter 2 mm, length 20 mm (L/D = 10).
%
% Method: for steady, fully developed, isothermal flow in a tube, the shear
% stress grows linearly from 0 at the centre to tau_w at the wall, and
%   pressure drop:  dP = 2 * L * tau_w / R
%   flow rate:      Q  = (pi * R^3 / tau_w^3) * integral from 0 to tau_w of tau^2 * gamma(tau) d(tau)
% (Rabinowitsch-Mooney equation). gamma(tau) comes from the viscosity model,
% so the same calculation works for any model: Newtonian, power law or Cross.
%
% Temperature: the Cross model of Sample B (190 C) is shifted to 210 and 230 C
% with the shift factors measured for Sample A:  eta_T(g) = aT * eta_190(aT * g).
% This assumes both polypropylenes respond to temperature in the same way.
%
% Data: data/processed/sampleB_model_fits.csv     (from fit_models.m)
%       data/processed/sampleA_shift_factors.csv  (from analyze_temperature.m)

clear; close all;

%% 1. Folders
scriptDir  = fileparts(mfilename('fullpath'));
projectDir = fileparts(scriptDir);
procDir    = fullfile(projectDir, 'data', 'processed');
figDir     = fullfile(projectDir, 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

%% 2. Inputs
fits  = readtable(fullfile(procDir, 'sampleB_model_fits.csv'));
shift = readtable(fullfile(procDir, 'sampleA_shift_factors.csv'));

cr   = strcmp(fits.model, 'Cross');
pl   = strcmp(fits.model, 'Power law');
eta0 = fits.eta0_Pa_s(cr);   lambda = fits.lambda_s(cr);   nC = fits.n(cr);
K    = fits.K_Pa_s_n(pl);    nPL    = fits.n(pl);

crossFun = @(g) eta0 ./ (1 + (lambda * g).^(1 - nC));
plFun    = @(g) K * g.^(nPL - 1);
newtFun  = @(g) eta0 * ones(size(g));      % Newtonian: viscosity stays at the plateau value

D   = 2e-3;      % die diameter, m
R   = D / 2;     % die radius, m
L   = 20e-3;     % die length, m
rho = 750;       % typical density of molten polypropylene, kg/m^3 (assumption)

mdotTarget = 1;  % example throughput for the comparison, kg/h

%% 3. Pressure drop vs. throughput
mdot = logspace(-2, 1, 100)';   % 0.01 to 10 kg/h

[dpNewt, gwNewt] = dieCurve(newtFun,  R, L, rho, mdot);
[dpPL,   gwPL]   = dieCurve(plFun,    R, L, rho, mdot);
[dpCross, gwCross] = dieCurve(crossFun, R, L, rho, mdot);

temps = [190 210 230];
dpT   = zeros(numel(mdot), numel(temps));
for i = 1:numel(temps)
    aT = shift.shift_factor_aT(shift.temperature_C == temps(i));
    dpT(:, i) = dieCurve(@(g) aT * crossFun(aT * g), R, L, rho, mdot);
end

%% 4. Results at the example throughput
at1 = @(dp) interp1(log10(mdot), dp, log10(mdotTarget));

names = ["Newtonian (190 C)"; "Power law (190 C)"; "Cross (190 C)"; "Cross (210 C)"; "Cross (230 C)"];
dp1   = [at1(dpNewt); at1(dpPL); at1(dpCross); at1(dpT(:, 2)); at1(dpT(:, 3))];
gw1   = [at1(gwNewt); at1(gwPL); at1(gwCross); NaN; NaN];

results = table(names, round(dp1, 1), round(gw1), ...
    'VariableNames', {'case', 'pressure_drop_bar', 'wall_shear_rate_1_per_s'});
fprintf('Die: D = %.0f mm, L = %.0f mm. Throughput: %.0f kg/h\n', D * 1e3, L * 1e3, mdotTarget);
disp(results);
writetable(results, fullfile(procDir, 'die_pressure_results.csv'));

%% 5. Figure
fig = figure('Color', 'w', 'Position', [100 100 1250 480]);
try
    theme(fig, 'light');   % keep a white background even if MATLAB is in dark mode
catch
end
tl = tiledlayout(1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

purple = [0.49 0.18 0.56];
green  = [0.47 0.67 0.19];
grey   = [0.50 0.50 0.50];
tempColors = [0.00 0.45 0.74; 0.47 0.67 0.19; 0.85 0.33 0.10];
deg = char(176);

% --- (a) Effect of the viscosity model at 190 C
nexttile
plot(mdot, dpNewt, '--', 'Color', grey, 'LineWidth', 1.8);
hold on
plot(mdot, dpPL, ':', 'Color', green, 'LineWidth', 2.2);
plot(mdot, dpCross, '-', 'Color', 'k', 'LineWidth', 1.8);
xline(mdotTarget, '-', sprintf('%.0f kg/h', mdotTarget), 'Color', [0.6 0.6 0.6], ...
      'HandleVisibility', 'off', 'LabelVerticalAlignment', 'bottom');
hold off
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on
xlabel('Throughput per die hole (kg/h)');
ylabel('Pressure drop in the die (bar)');
title(sprintf('(a) Viscosity model, 190 %sC', deg));
legend({'Newtonian (constant viscosity)', ...
        sprintf('Power law (n = %.2f)', nPL), ...
        sprintf('Cross (n = %.2f)', nC)}, 'Location', 'northwest');

% --- (b) Effect of temperature (Cross model)
nexttile
hold on
for i = 1:numel(temps)
    plot(mdot, dpT(:, i), '-', 'Color', tempColors(i, :), 'LineWidth', 1.8);
end
xline(mdotTarget, '-', sprintf('%.0f kg/h', mdotTarget), 'Color', [0.6 0.6 0.6], ...
      'HandleVisibility', 'off', 'LabelVerticalAlignment', 'bottom');
hold off
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on
xlabel('Throughput per die hole (kg/h)');
ylabel('Pressure drop in the die (bar)');
title('(b) Melt temperature (Cross model)');
legend(string(temps) + " " + deg + "C", 'Location', 'northwest');

title(tl, sprintf('Extrusion through a %.0f mm x %.0f mm strand die', D * 1e3, L * 1e3), ...
      'FontWeight', 'bold');

%% 6. Save
outFile = fullfile(figDir, 'die_pressure.png');
exportgraphics(fig, outFile, 'Resolution', 300);
disp(['Saved: ' outFile]);

%% Local function
function [dP, gw] = dieCurve(etaFun, R, L, rho, mdot)
    % Pressure drop (bar) and wall shear rate (1/s) at the requested
    % throughputs mdot (kg/h), for a fluid with viscosity function etaFun.
    g   = logspace(-8, 7, 6000);          % shear rates from almost zero to very high
    tau = etaFun(g) .* g;                 % shear stress at each shear rate
    I   = cumtrapz(tau, tau.^2 .* g);     % Rabinowitsch-Mooney integral
    Q   = pi * R^3 * I ./ tau.^3;         % flow rate if tau were the wall stress, m^3/s
    m   = Q * rho * 3600;                 % throughput, kg/h
    dPall = 2 * L * tau / R / 1e5;        % pressure drop, bar

    ok = m > 0;                           % skip the first point (zero flow)
    dP = interp1(log10(m(ok)), dPall(ok), log10(mdot));
    gw = 10.^interp1(log10(m(ok)), log10(g(ok)), log10(mdot));
end
