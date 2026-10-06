%% L_Plot_FullCatalog.m
% Four histogram figures for the full 2015-2021 FM catalog.
%
% Replaces Histograms of Full Catalog (histogramAll1-4.jpg).
%
% Yellow bar   : all SP>=5 events from A_All.mat per bin
% Stacked bars : N (blue) | R (red) | S (green) | U (black)
%                from Event1D_3D_Final.mat (all quality grades)
%
% Figure 1: 30-day bins — full y-axis
% Figure 2: 30-day bins — y capped at 90th percentile
% Figure 3: 10-day bins — full y-axis
% Figure 4: 10-day bins — y capped at 90th percentile
%
% Requires: A_All.mat and Event1D_3D_Final.mat in 02-data/.

clc; clear; close all;
if ~exist('cfg','var'); run('config.m'); end
addpath(cfg.subcodeDir);

%% ---- Colors ----
colYellow = [0.9  0.9  0.1 ];   % SP>=5 events (background)
colN      = [0    0    1   ];   % Normal       — blue
colR      = [1    0    0   ];   % Reverse      — red
colS      = [0    0.7  0   ];   % Strike-slip  — green
colU      = [0    0    0   ];   % Unclassified — black

%% ---- Output directories ----
graphicsDir = cfg.graphicsDir;
htdocs      = cfg.htdocs;
if ~exist(graphicsDir, 'dir'); mkdir(graphicsDir); end

%% ============================================================
%% 1.  Load SP>=5 base catalog times (A_All.mat)
%% ============================================================
load(fullfile(cfg.dataDir, 'A_All.mat'));   % Felix
base_on = [Felix.on];
fprintf('A_All: %d SP>=5 events  (%s to %s)\n', numel(base_on), ...
    datestr(min(base_on),'yyyy-mm'), datestr(max(base_on),'yyyy-mm'));
clear Felix;

%% ============================================================
%% 2.  Load FM catalog and extract times (Event1D_3D_Final.mat)
%% ============================================================
load(fullfile(cfg.dataDir, 'Event1D_3D_Final.mat'));  % event3D, Po_Clu

fprintf('FM catalog: %d events (all quality grades)\n', numel(event3D));

% Map cluster id -> origin time via Po_Clu
clust_vec = [Po_Clu.Cluster];
on_vec    = [Po_Clu.on];

fm_on   = nan(1, numel(event3D));
fm_type = {event3D.faultType};

for i = 1:numel(event3D)
    idx = find(clust_vec == event3D(i).id, 1, 'first');
    if ~isempty(idx)
        fm_on(i) = on_vec(idx);
    end
end

% Remove events where time lookup failed
valid = ~isnan(fm_on);
fm_on   = fm_on(valid);
fm_type = fm_type(valid);
fprintf('  Time resolved for %d / %d FM events.\n', sum(valid), numel(event3D));

% Separate by fault type
t_N = fm_on(strcmp(fm_type, 'N'));
t_R = fm_on(strcmp(fm_type, 'R'));
t_S = fm_on(strcmp(fm_type, 'S'));
t_U = fm_on(strcmp(fm_type, 'U'));
fprintf('  N=%d  R=%d  S=%d  U=%d\n', numel(t_N), numel(t_R), numel(t_S), numel(t_U));

%% ============================================================
%% 3.  Time axis common setup
%% ============================================================
tMin = min([base_on, fm_on]);
tMax = max([base_on, fm_on]);

updStr  = datestr(datetime('now','TimeZone','UTC'), 'dd-mmm-yyyy HH:MM');
figSz   = [100 100 950 800];
paperSz = [9.5 8.0];

outNames = {'fmCatalogAll1','fmCatalogAll2','fmCatalogAll3','fmCatalogAll4'};

%% ============================================================
%% 4.  Four figures: 30-day bins (full + capped), 10-day bins (full + capped)
%% ============================================================
for kfig = 1:4

    %% ---- Bin edges ----
    if kfig <= 2
        binDays  = 30;
        binLabel = '30-day bins';
    else
        binDays  = 10;
        binLabel = '10-day bins';
    end
    edges   = floor(tMin) : binDays : (ceil(tMax) + binDays);
    centers = edges(1:end-1) + binDays/2;

    %% ---- Bin counts ----
    base_cnt = histcounts(base_on, edges)';   % [nBins x 1]
    fm_N_cnt = histcounts(t_N, edges)';
    fm_R_cnt = histcounts(t_R, edges)';
    fm_S_cnt = histcounts(t_S, edges)';
    fm_U_cnt = histcounts(t_U, edges)';
    fm_stack = [fm_N_cnt, fm_R_cnt, fm_S_cnt, fm_U_cnt];  % [nBins x 4]

    %% ---- Figure ----
    fig = figure('Position', figSz, 'InvertHardcopy','off', 'Color','white');
    set(fig,'PaperUnits','inches','PaperSize',paperSz,'PaperPosition',[0 0 paperSz]);
    ax = axes('Parent', fig, 'Position', [0.12 0.20 0.83 0.60]);

    % Yellow background bar (SP>=5 events)
    h0 = bar(ax, centers, base_cnt, 1, 'EdgeColor','none', 'FaceColor',colYellow);
    hold(ax, 'on');

    % Stacked FM bars (N / R / S / U from bottom)
    hb = bar(ax, centers, fm_stack, 1, 'stacked', 'EdgeColor','none');
    hb(1).FaceColor = colN;
    hb(2).FaceColor = colR;
    hb(3).FaceColor = colS;
    hb(4).FaceColor = colU;

    %% ---- Axes formatting ----
    xlim(ax, [tMin - binDays/2,  tMax + binDays/2]);
    % One tick per year for dense, readable x-axis
    yr1 = year(datetime(tMin,'ConvertFrom','datenum'));
    yr2 = year(datetime(tMax,'ConvertFrom','datenum'));
    set(ax, 'XTick', datenum(yr1:yr2, 1, 1), ...
            'XTickLabel', string(yr1:yr2), ...
            'FontSize', 48, 'GridLineStyle', '-');
    ylabel(ax, 'Earthquakes per bin', 'FontSize', 52);
    grid(ax, 'on');

    %% ---- y-axis cap ----
    capStr = '';
    if mod(kfig,2) == 0   % figures 2 and 4 are capped
        ymax   = prctile(base_cnt(base_cnt > 0), 90);
        ylim(ax, [0, ymax]);
        capStr = ' — y capped at 90th pct';
    end

    %% ---- Legend and title ----
    legend(ax, [h0, hb(1), hb(2), hb(3), hb(4)], ...
        {'SP\geq5 events','Normal','Reverse','Strike-slip','Unclassified'}, ...
        'Location','northeast', 'FontSize', 38);

    title(ax, sprintf('Full Catalog 2015-2021  %s%s\nUpdated %s UTC', ...
        binLabel, capStr, updStr), 'FontSize', 52);

    %% ---- Save ----
    fname     = fullfile(graphicsDir, [outNames{kfig} '.jpg']);
    htdocsFname = fullfile(htdocs, [outNames{kfig} '.jpg']);
    exportgraphics(fig, fname, 'Resolution', 200, 'BackgroundColor', 'white');
    copyfile(fname, htdocsFname);
    close(fig);
    fprintf('Saved: %s.jpg\n', outNames{kfig});

end

fprintf('Done — 4 full-catalog histogram figures saved.\n');

%% ---- Regenerate website HTML ----
% Website update handled by I_UpdateFMWebsite.m (final pipeline stage)
