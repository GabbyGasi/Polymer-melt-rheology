% prepare_data.m
% Converts the WebPlotDigitizer exports in data/raw into clean data files
% in data/processed.
%
% Source: NETZSCH Application Note AN 297 (Strasser & Gezgin, 2023),
%         "Polymers and Temperature - A Hot Relationship"
%   Figure 1: shear viscosity of polypropylene (Sample A) at 190-230 C
%   Figure 5: shear viscosity of a second polypropylene (Sample B) at 190 C,
%             rotational rheometer + capillary rheometer
%
% Note on the conversion:
% Both charts have LOGARITHMIC axes, but the points were digitized with a
% LINEAR axis calibration in WebPlotDigitizer. A linear calibration is just
% a straight-line map of pixel position, so the true values can be recovered
% exactly: for calibration values a and b, a digitized value v lies a
% fraction f = (v - a)/(b - a) of the way along the axis, and the true
% value is  10^( log10(a) + f * log10(b/a) ).

clear;

%% 1. Folders
scriptDir  = fileparts(mfilename('fullpath'));
projectDir = fileparts(scriptDir);
rawDir     = fullfile(projectDir, 'data', 'raw');
outDir     = fullfile(projectDir, 'data', 'processed');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 2. Sample A (Figure 1): five temperatures
% Calibration used: x from 0.01 to 100 1/s, y from 0.1 to 10000 Pa.s
temps = [190 200 210 220 230];
T_all = [];  gamma_all = [];  eta_all = [];

for T = temps
    raw   = readmatrix(fullfile(rawDir, sprintf('fig1_%dC_wpd.csv', T)));
    gamma = linToLog(raw(:, 1), 0.01, 100);     % shear rate, 1/s
    eta   = linToLog(raw(:, 2), 0.1, 10000);    % viscosity, Pa.s

    T_all     = [T_all; T * ones(size(gamma))];
    gamma_all = [gamma_all; gamma];
    eta_all   = [eta_all; eta];
end

A = table(T_all, round(gamma_all, 4, 'significant'), round(eta_all, 4, 'significant'), ...
    'VariableNames', {'temperature_C', 'shear_rate_1_per_s', 'viscosity_Pa_s'});
A = sortrows(A, {'temperature_C', 'shear_rate_1_per_s'});
writetable(A, fullfile(outDir, 'sampleA_viscosity_5temps.csv'));

%% 3. Sample B (Figure 5): 190 C, rotational + capillary
% Calibration used: x from 0.001 to 100000 1/s, y from 1 to 10000 Pa.s
rotRaw = readmatrix(fullfile(rawDir, 'fig5_rotational_190C_wpd.csv'));
capRaw = readmatrix(fullfile(rawDir, 'fig5_capillary_190C_wpd.csv'));

rot = sortrows([linToLog(rotRaw(:, 1), 0.001, 1e5), linToLog(rotRaw(:, 2), 1, 1e4)]);
cap = sortrows([linToLog(capRaw(:, 1), 0.001, 1e5), linToLog(capRaw(:, 2), 1, 1e4)]);

% Remove accidental double clicks: points less than 10% apart in shear rate
keepRot = [true; diff(log10(rot(:, 1))) > log10(1.1)];
keepCap = [true; diff(log10(cap(:, 1))) > log10(1.1)];
fprintf('Removed %d duplicate rotational point(s) and %d duplicate capillary point(s).\n', ...
    sum(~keepRot), sum(~keepCap));
rot = rot(keepRot, :);
cap = cap(keepCap, :);

method = [repmat("rotational", size(rot, 1), 1); repmat("capillary", size(cap, 1), 1)];
B = table(method, round([rot(:, 1); cap(:, 1)], 4, 'significant'), ...
    round([rot(:, 2); cap(:, 2)], 4, 'significant'), ...
    'VariableNames', {'method', 'shear_rate_1_per_s', 'viscosity_Pa_s'});
writetable(B, fullfile(outDir, 'sampleB_flowcurve_190C.csv'));

%% 4. Quick check against the values stated by NETZSCH
disp('Sample A: average of the first 5 points (plateau viscosity):');
for T = temps
    rows = A.temperature_C == T;
    eta  = A.viscosity_Pa_s(rows);
    fprintf('  %d C: %.0f Pa.s\n', T, mean(eta(1:5)));
end
disp('(NETZSCH states about 1700 Pa.s at 190 C and 500 Pa.s at 230 C)');
fprintf('Sample B: %d rotational + %d capillary points, %.3g to %.3g 1/s\n', ...
    size(rot, 1), size(cap, 1), min(rot(:, 1)), max(cap(:, 1)));
disp('Saved sampleA_viscosity_5temps.csv and sampleB_flowcurve_190C.csv in data/processed');

%% Local function
function out = linToLog(v, a, b)
    % Recover the true value on a log axis from a linear calibration
    f   = (v - a) ./ (b - a);
    out = 10 .^ (log10(a) + f .* log10(b / a));
end
