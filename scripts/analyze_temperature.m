% analyze_temperature.m
% Graph 1: How temperature changes the melt viscosity of polypropylene (Sample A)
%
% (a) Measured viscosity vs. shear rate at 190-230 C
% (b) Master curve: all temperatures shifted onto the 190 C curve
%     (time-temperature superposition)
% (c) Arrhenius plot: shift factors vs. 1/T -> flow activation energy Ea
%
% Data: data/processed/sampleA_viscosity_5temps.csv
%       (NETZSCH AN 297, Figure 1, digitized with WebPlotDigitizer)

clear; close all;

%% 1. Folders
scriptDir  = fileparts(mfilename('fullpath'));
projectDir = fileparts(scriptDir);
dataFile   = fullfile(projectDir, 'data', 'processed', 'sampleA_viscosity_5temps.csv');
figDir     = fullfile(projectDir, 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

%% 2. Load the data and keep only reliable points
A = readtable(dataFile);

gammaMax = 4;   % above ~4 1/s the melt is pushed out of the rheometer gap (measurement artifact)
A = A(A.shear_rate_1_per_s <= gammaMax, :);

temps = unique(A.temperature_C);   % 190, 200, 210, 220, 230
nT    = numel(temps);
Tref  = 190;                       % reference temperature, C
R     = 8.314;                     % gas constant, J/(mol K)

%% 3. Zero-shear viscosity and shift factors
% eta0 = average viscosity on the flat plateau (shear rate <= 0.1 1/s)
eta0 = zeros(nT, 1);
for i = 1:nT
    rows    = A.temperature_C == temps(i) & A.shear_rate_1_per_s <= 0.1;
    eta0(i) = mean(A.viscosity_Pa_s(rows));
end

% Shift factor: how much lower the viscosity is than at the reference temperature
aT = eta0 / eta0(temps == Tref);

%% 4. Arrhenius fit:  ln(aT) = (Ea/R) * (1/T - 1/Tref)
TK = temps + 273.15;                        % temperature in kelvin

p   = polyfit(1 ./ TK, log(aT), 1);         % all five temperatures
Ea  = p(1) * R / 1000;                      % kJ/mol
yfit = polyval(p, 1 ./ TK);
R2  = 1 - sum((log(aT) - yfit).^2) / sum((log(aT) - mean(log(aT))).^2);

lowT  = temps <= 210;                       % the three lowest temperatures only
pLow  = polyfit(1 ./ TK(lowT), log(aT(lowT)), 1);
EaLow = pLow(1) * R / 1000;

results = table(temps, round(eta0), round(aT, 3), ...
    'VariableNames', {'temperature_C', 'eta0_Pa_s', 'shift_factor_aT'});
disp(results);
fprintf('Activation energy, 190-230 C: Ea = %.1f kJ/mol (R^2 = %.3f)\n', Ea, R2);
fprintf('Activation energy, 190-210 C: Ea = %.1f kJ/mol\n', EaLow);
writetable(results, fullfile(projectDir, 'data', 'processed', 'sampleA_shift_factors.csv'));

%% 5. Figure
fig = figure('Color', 'w', 'Position', [100 100 1400 450]);
try
    theme(fig, 'light');   % keep a white background even if MATLAB is in dark mode
catch
end
tl = tiledlayout(1, 3, 'TileSpacing', 'loose', 'Padding', 'compact');

colors = [0.00 0.45 0.74;    % 190 C
          0.30 0.75 0.93;    % 200 C
          0.47 0.67 0.19;    % 210 C
          0.93 0.69 0.13;    % 220 C
          0.85 0.33 0.10];   % 230 C
deg    = char(176);          % degree sign
labels = string(temps) + " " + deg + "C";

% --- (a) Measured viscosity
nexttile
hold on
for i = 1:nT
    rows = A.temperature_C == temps(i);
    plot(A.shear_rate_1_per_s(rows), A.viscosity_Pa_s(rows), 'o-', 'Color', colors(i, :), ...
         'MarkerFaceColor', colors(i, :), 'MarkerSize', 4, 'LineWidth', 1.2);
end
hold off
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on
xlim([0.005 10]);  ylim([300 6000]);
yticks([300 500 1000 2000 5000]);
xlabel('Shear rate (1/s)');
ylabel('Viscosity (Pa\cdots)');
title('(a) Measured viscosity');
legend(labels, 'Location', 'northeast');

% --- (b) Master curve
nexttile
hold on
for i = 1:nT
    rows = A.temperature_C == temps(i);
    plot(aT(i) * A.shear_rate_1_per_s(rows), A.viscosity_Pa_s(rows) / aT(i), 'o', ...
         'Color', colors(i, :), 'MarkerFaceColor', colors(i, :), 'MarkerSize', 4);
end
hold off
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on
xlim([0.002 10]);  ylim([300 6000]);
yticks([300 500 1000 2000 5000]);
xlabel('Reduced shear rate  a_T \times shear rate (1/s)');
ylabel('Reduced viscosity  \eta / a_T (Pa\cdots)');
title(sprintf('(b) Master curve at %d %sC', Tref, deg));
legend(labels, 'Location', 'northeast');

% --- (c) Arrhenius plot
nexttile
xf = linspace(min(1 ./ TK), max(1 ./ TK), 50);
plot(1000 ./ TK, log(aT), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
hold on
plot(1000 * xf, polyval(p, xf), '-', 'Color', [0.80 0.10 0.10], 'LineWidth', 1.5);
plot(1000 * xf, polyval(pLow, xf), '--', 'Color', [0.40 0.40 0.40], 'LineWidth', 1.5);
text(1000 ./ TK + 0.004, log(aT) - 0.06, labels, 'FontSize', 9);
hold off
grid on
ylim([-1.45 0.25]);
xlabel('1000 / T (1/K)');
ylabel('ln a_T');
title('(c) Arrhenius plot');
legend({'Data', ...
        sprintf('Fit 190-230 %sC: E_a = %.0f kJ/mol', deg, Ea), ...
        sprintf('Fit 190-210 %sC: E_a = %.0f kJ/mol', deg, EaLow)}, ...
       'Location', 'northwest');

title(tl, 'Polypropylene (Sample A): effect of temperature on melt viscosity', 'FontWeight', 'bold');

%% 6. Save
outFile = fullfile(figDir, 'temperature_dependence.png');
exportgraphics(fig, outFile, 'Resolution', 300);
disp(['Saved: ' outFile]);
