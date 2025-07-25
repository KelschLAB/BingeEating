clear
addpath(genpath(cd))
load("SM_Berlin.mat") % These are the spikes (for the CCA and statistical tests)
load("iFR_Berlin.mat") % This is the smoothed firing rate (for plotting PSTHs)
Sessions = unique(Units.Name, 'Stable'); % This is the formal name of each session
Mauser = NaN(numel(Sessions),1); % and its corresponding mouse ID
for s = 1:numel(Sessions)
    Ixer = find(Units.Name==Sessions(s));
    Mauser(s) = Units.Mouse(Ixer(1));
end
Mish = unique(Mauser); % ID of the mice

%% Canonical correlation analysis (CCA)
% You can produce these results yourself or skip to the next section and
% load them. Producing them will be very time-consuming. 

W = 2; % I will take 2s of data per CCA (per trial, aligned with trial onset)
Window = -2:0.1:2.7+3; % This array shows the last instant taken for the analysis. For
% example, the first window taken goes from -4s to -2s. % We will run the CCA from -4s 
% from stimulus onset to after 4s after the reward
L =.6; % The lagged CCA will be lagged with a maximum abs(lag) of 600ms
Lagger = [];
Adder = 0.025;
Multer = Adder;
enner = 0;
perer = 0;
while Adder < L % 
    Lagger = cat(2, Lagger, Adder);
    if enner.*Multer<0.1
        if mod(perer,10)==0
            enner = enner+1;
        end
        perer = perer+1;
    end
    Adder = Adder + enner.*Multer;
end
Lagger_AtoO = -Lagger; % These are the lags from aPC to OT. This means that the aPC has a negative lag w.r.t. the OT. 
Lagger = cat(2, 0, Lagger);
Lagger = -Lagger(end:-1:1); % Lags from OT to aPC and the zero-lag (simultaneous activity)

Binning = 0.1; % The two-second window W will be binned in bins of 100ms (20 bins per trial)
Contains = W/Binning; % 20 bins per trial

nboot = 100.*48; % I will perform 4800 shuffles for the statistical test. This is because I have 48 CPUs.
% The shuffle test calculates the canonical correlation (r) after breaking
% the trial-to-trial correspondance between aPC and OT, but preserving
% trial type (there are four trial types: C100, C0, C50N, and C50R. Bellow,
% I index them as Uno, Dos, Tres and Quat. We at KelschLab are aware that
% the Spanish number 4 is written with C and not with Q, so please refrain
% from qorrecting us.)
R_Saver = NaN(numel(Lagger)+numel(Lagger_AtoO), numel(Window), 3, size(Sessions,1)); % r-value, bst z-score, p-value
% In the third dimension, the R_Saver structure keeps, for each lag (first dimension) and for each
% window (second dimension), the original r-value, the z-score against the bootstrap distribution, and
% the p-value against the same distribution. It does this for all sessions (fourth dimension) 
dNature = NaN(numel(Lagger)+numel(Lagger_AtoO), numel(Window), 1, size(Sessions,1)); % c.nature (cv)
% This Nature structure is very similar to R_Saver, and it keeps the nature
% of the correlation, which in the paper we call "d", in the third dimension 
for s = 1:numel(Sessions)  % For each session
    tic % (This is just to time how long it takes to do the CCA)
    OT = find(Units.Name==Sessions(s) & Units.Region==2); % These are my OT units 
    if isempty(OT); continue; end % If there are none, then the session is discarded from the analysis 
    Beit = SM(OT); % This is the spike train of the OT units (in seconds)
    ST_ = TM(OT(1),1,:); % These are the times at which the CS appears (in seconds). The third dimension contains the 150 trials. 
    Trials = sum(~isnan(ST_(1,1,:))); % How many trials are there? Spoiler: always 150.
    ST_ = squeeze(ST_(:, :, 1:Trials))';
    Stimuli_ = TM(OT(1),2,:); % This is the identity of the stimulus in the trial (CS100, CS50, CS0)
    Stimuli_ = squeeze(Stimuli_(:, :, 1:Trials))';
    Doer = 1:Trials; % We want to analyze all trials (but feel free to do less!)
    Typer = squeeze(TM(OT(1),3,1:Trials))'; % This is important for the shuffle test later: it is an index of each trial type along the 150 trials. 
        Uno = find(Typer == 5);
        Dos = find(Typer == 8);
        Tres = find(Typer == 10);
        Quat = find(Typer == 11);
    
    APC = find(Units.Name==Sessions(s) & Units.Region==1); % Same for aPC
    if isempty(APC); continue; end
    Aleph = SM(APC);    
    r_OtoA = NaN(numel(Lagger), numel(Window), 3); % This will be a temporary structure for the R_Saver
    d_OtoA = NaN(numel(Lagger), numel(Window), 4); % And this one for the correlation nature "d" 
    r_AtoO = NaN(numel(Lagger_AtoO), numel(Window), 3);
    d_AtoO = NaN(numel(Lagger_AtoO), numel(Window), 4);
    for disT = 1:numel(Window) % Now to the actual CCA: for each window...
%         From OT to aPC
        for lag = 1:numel(Lagger) % And for each lag...
            Time = Window(disT)-W:Binning:Window(disT); % Take this window
            X = zeros(numel(Aleph), Contains, numel(Doer)); % And arrange the aPC data by...
            for u = 1:numel(Aleph)
                spM = Aleph{u}; % by taking the spikes.
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        % This is where the binning happens
                        X(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta) & spM<ST_(Doer(tr))+Time(ta+1)); 
                    end
                end
            end
            X = reshape(X, size(X,1), size(X,2).*size(X,3))'; % Reshape the aPC binned spikes X
            Nanner = isnan(X(1,:)); % Remove any constant columns (units without spikes)
            X(:, Nanner) = [];
            if isempty(X); continue; end % If there is no data, then let's move on to the next window.
            
            Y = zeros(numel(Beit), Contains, numel(Doer)); % Do the same for the OT
            for u = 1:numel(Beit)
                spM = Beit{u};
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        % Notice that now I am lagging the OT activity by
                        % some negative quantity Lagger(lag)
                        Y(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta)+Lagger(lag) & spM<ST_(Doer(tr))+Time(ta+1)+Lagger(lag));
                    end
                end
            end
            
            Y = reshape(Y, size(Y,1), size(Y,2).*size(Y,3))';      
            Nanner = isnan(Y(1,:));
            Y(:, Nanner) = [];
            if isempty(Y); continue; end
            enne = size(Y,1);
            [A,B,r] = canoncorr(X, Y); % THIS IS WHERE I DO THE CCA
            if isempty(r); continue; end % This never happens in practice, but just in case. It could be that no canonical dimension is found significant, I think. 
            % Set the sum of the weights of the OB to be in general in the direction of coding. This answers whether coding in the TU inhibits the aPC 
            % r is my canonical correlation and A and B are the weights of
            % the units of aPC and OT
            d = (sum(A(:,1))./sum(abs(A(:,1)))).*(sum(B(:,1))./sum(abs(B(:,1)))); % Correlation nature as defined in the methods section (look for: Sign of the correlation)
            
            % SHUFFLE TEST
            r_zscore = NaN; % This was here for debugging reasons
            rBST = NaN(1,nboot); % I will save all the shuffle results r
            parfor bst = 1:nboot
                idx = NaN(size(Y,1),1);
                % Randomization of trials of the same type 
                Ixer = NaN(numel(Doer),1)
                Ixer(Uno(randperm(numel(Uno)))) = Uno;
                Ixer(Dos(randperm(numel(Dos)))) = Dos;
                Ixer(Tres(randperm(numel(Tres)))) = Tres;
                Ixer(Quat(randperm(numel(Quat)))) = Quat;
                for ra = 1:numel(Ixer)
                    idx(1 + (ra-1).*Contains : ra.*Contains) = 1 + (Ixer(ra)-1).*Contains : Ixer(ra).*Contains;
                end
                % Y usually has less units, so it was less computationally
                % expensive to shuffle Y and not X. 
                Y_ = Y;
                Y_=Y_(idx,:);
                [A,B,rbst] = canoncorr(X, Y_);
                rBST(:, bst) = rbst(:,1);
            end
            meanR = mean(rBST,2); % Mean shuffle r
            stdR = std(rBST,0,2); % std of shuffle r
            r_zscore = (r(1)-meanR)./stdR; % Z-SCORE OF THE ORIGINAL r AGAINST THE SHUFFLE DISTRIBUTION
            r_pvalue = mean(rBST>r(1)); % And its p-value (what fraction of r_shuffle is larger than r)

            r_OtoA(lag, disT, :) = cat(3, r(1), r_zscore, r_pvalue); % Save it
            d_OtoA(lag, disT, 1) = d;
        end
        % From OT to aPC
        for lag = 1:numel(Lagger_AtoO) % Ditto
            Time = Window(disT)-W:Binning:Window(disT); 
            X = zeros(numel(Aleph), Contains, numel(Doer));
            for u = 1:numel(Aleph)
                spM = Aleph{u};
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        % But notice that now it is the aPC that gets lagged negatively by Lagger_AtoO(lag) 
                        X(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta)+Lagger_AtoO(lag) & spM<ST_(Doer(tr))+Time(ta+1)+Lagger_AtoO(lag));
                    end
                end
            end
            X = reshape(X, size(X,1), size(X,2).*size(X,3))';
            Nanner = isnan(X(1,:));
            X(:, Nanner) = [];
            if isempty(X); continue; end

            Y = zeros(numel(Beit), Contains, numel(Doer));
            for u = 1:numel(Beit)
                spM = Beit{u};
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        Y(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta) & spM<ST_(Doer(tr))+Time(ta+1));
                    end
                end
            end
            Y = reshape(Y, size(Y,1), size(Y,2).*size(Y,3))';            
            Nanner = isnan(Y(1,:));
            Y(:, Nanner) = [];
            if isempty(Y); continue; end
            enne = size(Y,1);
            [A,B,r] = canoncorr(X, Y);
            if isempty(r); continue; end
            d = (sum(A(:,1))./sum(abs(A(:,1)))).*(sum(B(:,1))./sum(abs(B(:,1))));

            r_zscore = NaN;
            for hide = 1
            rBST = NaN(1,nboot);
            parfor bst = 1:nboot
                idx = NaN(size(Y,1),1);
                Ixer = NaN(numel(Doer),1)
                Ixer(Uno(randperm(numel(Uno)))) = Uno;
                Ixer(Dos(randperm(numel(Dos)))) = Dos;
                Ixer(Tres(randperm(numel(Tres)))) = Tres;
                Ixer(Quat(randperm(numel(Quat)))) = Quat;

                for ra = 1:numel(Ixer)
                    idx(1 + (ra-1).*Contains : ra.*Contains) = 1 + (Ixer(ra)-1).*Contains : Ixer(ra).*Contains;
                end
                Y_ = Y;
                Y_=Y_(idx,:);
                [A,B,rbst] = canoncorr(X, Y_);
                rBST(:, bst) = rbst(:,1);
            end
            meanR = mean(rBST,2);
            stdR = std(rBST,0,2);
            r_zscore = (r(1)-meanR)./stdR;
            r_pvalue = mean(rBST>r(1));
            end
            r_AtoO(lag, disT, :) = cat(3, r(1), r_zscore, r_pvalue);
            d_AtoO(lag, disT, 1) = d;
        end
    disT
    end
    R_Saver(:, :, :, s) = cat(1, r_OtoA, r_AtoO);
    dNature(:, :, 1, s) = cat(1, d_OtoA, d_AtoO);
    s
    toc
end
%% You should save R_Saver and Nature
% Since each shuffle run is (ever so slightly) different, here is my saved
% results. Also, you don't need to run your 48 CPUs for a full day. 
load("R_Saver_workspace.mat")
%% Now let's do the LME to see if the r is in general above the shuffle distribution
% Statistical significance of z-score r
LaggerAll = cat(2, Lagger, -Lagger_AtoO); % This is all lags put together (the 1st dimension of R_Saver and dNature)
Stat_R = NaN(numel(LaggerAll), size(R_Saver,2), 3);
for b = 1:size(R_Saver,2)
    parfor l = 1:numel(LaggerAll)
        R = squeeze(R_Saver(l, b, 2, :)); % Retrieve the z-score against shuffle of all CCAs (notice the number 2 in the 3rd dimension of R_Saver)
        if all(isnan(R), "all"); continue; end
        Mus = Mauser; % The LME needs the identity of each mouse
        Nanner = isnan(R);
        X = [R, Mus];
        X(Nanner,:) = [];
        X = array2table(X, "VariableNames", ["R", "Mouse"]);
        X.Mouse = categorical(X.Mouse);
        ster = 'R ~ 1 + (1|Mouse)';
        lme = fitlme(X, ster); 
        Stat_R(l, b, :) = cat(3, lme.Coefficients.Estimate(1), lme.Coefficients.SE(1), lme.Coefficients.pValue(1));
        if b==size(R_Saver,2) & l==numel(LaggerAll)
            "DF: " + lme.Coefficients.DF % I will want to know the DOF, so print them
        end
    end
    b % This will go up to 78
end

[max_x, ~] = max(Stat_R(1:numel(Lagger)-1,:,1)./Stat_R(1:numel(Lagger)-1,:,2), [], 1);
[~, max_x] = max(max_x);
[~, max_y] = max(Stat_R(1:numel(Lagger)-1,max_x,1)./Stat_R(1:numel(Lagger)-1,max_x,2));
["Maximum OT->aPC t-value at " + (Window(max_x)-(W/2)) + "-centered aPC window (x-axis)";...
"and " + Lagger(max_y) + " OT lags (y-axis)"]

% Window of interest:
"Mean effect size in WOI: "
"Beta ± SE = " + mean(Stat_R(6:7, 49:52, 1), "all") + " ± " + mean(Stat_R(6:7, 49:52, 2), "all")
"t-stat = " + mean(Stat_R(6:7, 49:52, 1)./Stat_R(6:7, 49:52, 2), "all")

figure % Interesting plots, but with caveats explained below:
    YAx = LaggerAll(1) : Multer/3 : LaggerAll(end); % These are for plotting
    YAx(abs(YAx)<0.001)=0;
    ms100 = .1 ./ (Multer/3);
    Ticker = round(Window,0);
nexttile
This = Stat_R(:,:,1)./Stat_R(:,:,2);
pVals = Stat_R(:,:,3); 
ThisM = double(pVals <= (0.05 ./ numel(pVals)));
ThisM(ThisM==0)=NaN;
Canvas = NaN(numel(YAx), numel(Window));
Mask = NaN(numel(YAx), numel(Window));
for b = 1:numel(YAx)
    [~, theser] = min(abs( LaggerAll-YAx(b) ));
    Canvas(b,:) = This(theser,:);
    Mask(b,:) = ThisM(theser,:);
end
This = Canvas.*Mask; This(end+1,:) = NaN; This(:, end+1) = NaN;
map = pcolor(This);
map.EdgeColor = "none";
ax = gca;
set(gca, 'YDir','reverse')
colorbar
title("zscore t-value")
% FIGURE 4P and S6C

nexttile
This = squeeze(mean(dNature(:, :, 1,:).*(R_Saver(:, :, 1,:)), 4, "omitnan"));
Canvas = NaN(numel(YAx), numel(Window));
for b = 1:numel(YAx)
    [~, theser] = min(abs( LaggerAll-YAx(b) ));
    Canvas(b,:) = This(theser,:);
end
imagesc(Canvas); %AsymmetricJet(gca, .05);
colorbar
title("Signal times nature")
% FIGURES 4Q and S6C

nexttile
This = squeeze(mean(R_Saver(:, :, 1,:), 4, "omitnan"));
Canvas = NaN(numel(YAx), numel(Window));
for b = 1:numel(YAx)
    [~, theser] = min(abs( LaggerAll-YAx(b) ));
    Canvas(b,:) = This(theser,:);
end
imagesc(Canvas); 
colorbar
title("r")
% FIGURE NOT IN THE PAPER: A high canonical correlation r does not mean significance. Actually, r scales with 
% the number of available units, for example. Why? Because if I have enough noisy units,
% I will always be able to find a set of weights to reproduce any other
% signal. This is why the z-score agains the shuffle distribution is more
% important than the actual r value. Still interesting to plot! In this
% case, we see high simultaneous-activity correlation - not surprising, and
% not significant!

nexttile
This = squeeze(mean(R_Saver(:, :, 2,:), 4, "omitnan"));
Canvas = NaN(numel(YAx), numel(Window));
for b = 1:numel(YAx)
    [~, theser] = min(abs( LaggerAll-YAx(b) ));
    Canvas(b,:) = This(theser,:);
end
imagesc(Canvas); 
colorbar
title("r zscore (against bst)")
% FIGURE NOT IN THE PAPER: A high mean z-score is good, but it can be due to an outlier mouse.
% This is why it is improtant to perform an LME, so that the identity of
% the subjects is taken into account as sources of evidence.

% Now make them pretty!
for ti = 1:4
    nexttile(ti)
    yline(find(YAx==0), "r")
    yticks(find(YAx==0)-5.*ms100:ms100.*2:numel(YAx))
    yticklabels(abs(YAx(find(YAx==0)-5.*ms100:ms100.*2:numel(YAx))))
    xline(find(Window<0.0001 & Window>-0.0001)-.5 +10,"r")
    xline(find(Window<0.0001 & Window>-0.0001)-.5 + 10 +10,"--r")
    xline(find(Window<2.70001 & Window>2.6999)-.5 +10,"r")
    xticks([1:10:numel(Ticker)]-.5)
    xticklabels(Ticker(1:10:end) -1)
    xtickangle(0)
    ylabel("Lag (s)")
    xlabel("Time (s)")
    colorbar
end

%% Now that we have the significance of the CCA, let's take a look at the subspaces
HowMany = NaN(size(Sessions,1), 2); % How many units per region in each session
for s = 1:size(Sessions,1)
    OT = find(Units.Name==Sessions(s) & Units.Region==2);
    APC = find(Units.Name==Sessions(s) & Units.Region==1);
    if isempty(OT) | isempty(APC); continue; end
    HowMany(s,1) = numel(OT);
    HowMany(s,2) = numel(APC);
end
Taker = ~isnan(HowMany(:,1,1)); % Sessions that have at least one unit in both regions

disL_AtoO = NaN(numel(Sessions), 1); % Obtain the most significant lags (y-axis of plots from the previous section)
disL_OtoA = NaN(numel(Sessions), 1);
disT_AtoO = NaN(numel(Sessions), 1); % and most significant windows (x-axis of plots from the previous section)
disT_OtoA = NaN(numel(Sessions), 1);
Z_AtoO = NaN(numel(Sessions), 1);
Z_OtoA = NaN(numel(Sessions), 1);
W_AtoO = 26:31; % This is the window of interest for the lag aPC->OT (aPC negatively lagged)
L_AtoO = 22:24; % and its lags of interest.
W_OtoA = 49:52; % Ditto for OT->aPC
L_OtoA = 6:8;
for s = 1:numel(Sessions)
    temp_AtoO = R_Saver(L_AtoO, W_AtoO, 3, s);
    temp_OtoA = R_Saver(L_OtoA, W_OtoA, 3, s);
    if all(isnan(temp_OtoA), "all"); continue; end
    
    d_AtoO = min(temp_AtoO, [], 1);
    [r_AtoO, d_AtoO] = min(d_AtoO);
    [~, l_AtoO] = min(temp_AtoO(:, d_AtoO));
    d_OtoA= min(temp_OtoA, [], 1);
    [r_OtoA, d_OtoA] = min(d_OtoA);
    [~, l_OtoA] = min(temp_OtoA(:, d_OtoA));
    
    disT_AtoO(s) = W_AtoO(d_AtoO);
    disT_OtoA(s) = W_OtoA(d_OtoA);
    disL_AtoO(s) = L_AtoO(l_AtoO);
    disL_OtoA(s) = L_OtoA(l_OtoA);
    Z_AtoO(s) = r_AtoO;
    Z_OtoA(s) = r_OtoA;
end
Select = Z_OtoA;
Select = sum(Select<0.05, 2)==1;
"There are " + sum(Select) + " out of " + sum(Taker) + " sessions where we have a significant bin with OT->aPC CCA in the window of interest"

fig = figure;
fig.Position = [997 1072 257 192];
bar(histcounts(Mauser(Taker)), 'BarWidth',1)
hold on
bar(histcounts(Mauser(Select)), 'BarWidth',1)
xlabel("Mouse")
ylabel("Sessions")
legend(["Analyzed", "Significant"], 'Location', 'northoutside')
% FIGURE S6A
% Mouse 5 didn't have any session with simultaneous recordings,
% so it got cut from the final figure. 

fig = figure;
fig.Position = [638 740 214 314];
nexttile
histogram(HowMany(:,1))
hold on
histogram(HowMany(Select,1))
xlabel("Units")
ylabel("Sessions")
title("OT")
nexttile
histogram(HowMany(:,2))
hold on
histogram(HowMany(Select,2))
xlabel("Units")
ylabel("Sessions")
title("aPC")
sgtitle("How many units in all vs significant sessions")
% FIGURE S6B

%% Run the CCA again in the selected bins from above in order to save their weights
Vect_Saver_AtoO = cell(2,size(Sessions,1)); % aPC then OT, bins, sessions
Vect_Saver_OtoA = cell(2,size(Sessions,1)); 
Vect_Saver_OtoA_raw = cell(2,size(Sessions,1)); 
Vect_Saver_OtoA_rawSpikes = cell(2,size(Sessions,1)); 
Vect_ID = cell(2,size(Sessions,1)); % 
CV_Saver = NaN(2,size(Sessions,1)); 
for s =  1:numel(Sessions) 
    if Select(s)==0; continue; end
    tic
    OT = find(Units.Name==Sessions(s) & Units.Region==2);
    if isempty(OT); continue; end

    Beit = SM(OT);  
    % Take all trials
    ST_ = TM(OT(1),1,:);
    Stimuli_ = TM(OT(1),2,:);
    Stimall_ = TM(OT(1),3,:);
    Trials = sum(~isnan(ST_(1,1,:)));
    ST_ = squeeze(ST_(:, :, 1:Trials))';
    Stimuli_ = squeeze(Stimuli_(:, :, 1:Trials))';
    Stimall_ = squeeze(Stimall_(:, :, 1:Trials))';
    
    Doer = 1:Trials; 
    
    APC = find(Units.Name==Sessions(s) & Units.Region==1);
    Vect_ID{1, s} = APC;
    Vect_ID{2, s} = OT;
    if isempty(APC); continue; end
    Aleph = SM(APC);    
    for disT = disT_OtoA(s)
        for hide = 1
        % OT to aPC
        for lag = disL_OtoA(s)
            Time = Window(disT)-W:Binning:Window(disT); 
            X = zeros(numel(Aleph), Contains, numel(Doer));
            for u = 1:numel(Aleph)
                spM = Aleph{u};
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        X(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta) & spM<ST_(Doer(tr))+Time(ta+1));
                    end
                end
            end
            X = reshape(X, size(X,1), size(X,2).*size(X,3))';
            % Z-score units (Necessary for the rasterplots)
            X_raw = X;
            X = (X-mean(X,1))./std(X,0,1);
            Nanner = isnan(X(1,:));
            X(:, Nanner) = [];
            if isempty(X); continue; end
            
            Y = zeros(numel(Beit), Contains, numel(Doer));
            for u = 1:numel(Beit)
                spM = Beit{u};
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        Y(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta)+Lagger(lag) & spM<ST_(Doer(tr))+Time(ta+1)+Lagger(lag));
                    end
                end
            end
            % Z-score units (Necessary for the rasterplots)
            Y_raw = Y;
            Y = (Y-mean(Y,[2,3]))./std(Y,0,[2,3]);
            Y = reshape(Y, size(Y,1), size(Y,2).*size(Y,3))';            
            Y_raw = reshape(Y_raw, size(Y_raw,1), size(Y_raw,2).*size(Y_raw,3))';            
            Nanner = isnan(Y(1,:));
            Y(:, Nanner) = [];
            if isempty(Y); continue; end
            [A,B,r] = canoncorr(X, Y);
            [A_raw,B_raw,r] = canoncorr(X_raw, Y_raw);
            if isempty(r); continue; end
            Vect_Saver_OtoA{1, s} = A(:,1);
            Vect_Saver_OtoA{2, s} = B(:,1);
            Vect_Saver_OtoA_raw{1, s} = A_raw(:,1);
            Vect_Saver_OtoA_raw{2, s} = B_raw(:,1);
            Vect_Saver_OtoA_rawSpikes{1, s} = sum(X_raw,1);
            Vect_Saver_OtoA_rawSpikes{2, s} = sum(Y_raw,1);
            sumA = sum(A(:,1))./sum(abs(A(:,1)));
            sumB = sum(B(:,1))./sum(abs(B(:,1)));
            C_OT_tris = sumA.*sumB; 
            CV_Saver(2, s) = C_OT_tris;
        end
        end
    end
    for disT = disT_AtoO(s)
        for lag = disL_AtoO(s)-numel(Lagger)
            Time = Window(disT)-W:Binning:Window(disT); 
            X = zeros(numel(Aleph), Contains, numel(Doer));
            for u = 1:numel(Aleph)
                spM = Aleph{u};
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        X(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta)+Lagger_AtoO(lag) & spM<ST_(Doer(tr))+Time(ta+1)+Lagger_AtoO(lag));
                    end
                end
            end
            X = reshape(X, size(X,1), size(X,2).*size(X,3))';
            % Z-score units (Necessary for the rasterplots)
            X = (X-mean(X,1))./std(X,0,1);
            Nanner = isnan(X(1,:));
            X(:, Nanner) = [];
            if isempty(X); continue; end

            Y = zeros(numel(Beit), Contains, numel(Doer));
            for u = 1:numel(Beit)
                spM = Beit{u};
                for ta = 1:Contains
                    for tr = 1:numel(Doer)
                        Y(u, ta, tr) = sum(spM>ST_(Doer(tr))+Time(ta) & spM<ST_(Doer(tr))+Time(ta+1));
                    end
                end
            end
            % Z-score units (Necessary for the rasterplots)
            Y = (Y-mean(Y,[2,3]))./std(Y,0,[2,3]);
            Y_bst = Y;
            Y = reshape(Y, size(Y,1), size(Y,2).*size(Y,3))';            
            Nanner = isnan(Y(1,:));
            Y(:, Nanner) = [];
            if isempty(Y); continue; end
            enne = size(Y,1);
            [A,B,r] = canoncorr(X, Y);
            if isempty(r); continue; end
            Vect_Saver_AtoO{1, s} = A(:,1);
            Vect_Saver_AtoO{2, s} = B(:,1);
            sumA = sum(A(:,1))./sum(abs(A(:,1)));
            sumB = sum(B(:,1))./sum(abs(B(:,1)));
            C_aPC_tris = sumA.*sumB; 
            CV_Saver(1, s) = C_aPC_tris;
        end    
    end
    s
    toc
end
%% Are the units in OtoA doing what we believe? PSTH of absoluteweight projection
Ser = find(Select);
Mer = Mauser(Ser);
M_A = NaN(numel(Ser), size(iFR,2), size(TM,3)); % CC FR
Mp_A = NaN(numel(Ser), size(iFR,2), size(TM,3)); % CC projection
Normal_A = NaN(numel(Ser), size(iFR,2), size(TM,3)); % Region FR
SM_A = NaN(numel(Ser), 2, size(TM,3)); % Small FR for LME later
wSM_A = NaN(numel(Ser), 2, size(TM,3)); % Small CC proj for LME later
M_O = NaN(numel(Ser), size(iFR,2), size(TM,3));
Mp_O = NaN(numel(Ser), size(iFR,2), size(TM,3));
SM_O = NaN(numel(Ser), 2, size(TM,3));
wSM_O = NaN(numel(Ser), 2, size(TM,3));
Normal_O = NaN(numel(Ser), size(iFR,2), size(TM,3));
TM_ = NaN(numel(Ser), size(TM,2), size(TM,3));
Misher = NaN(numel(Ser));
for s = 1:numel(Ser)
    Misher(s) = Mauser(Ser(s));
    ixA = Vect_ID{1,Ser(s)};
    ST_ = TM(ixA(1),1,:);
    disTM = squeeze(TM(ixA(1),2,:));
    wA = Vect_Saver_OtoA_raw{1,Ser(s)};
    bA = (Vect_Saver_OtoA_rawSpikes{1,Ser(s)}./(150.*2))';
    actA = iFR(ixA,:,:);
    Normal_A(s,:,:) = mean(actA,1);
    M_A(s,:,:) = sum(actA.*abs(wA), 1)  ./ sum(abs(wA));
    projA = sum((actA-bA).*wA, 1) ;
    smA = NaN(numel(ixA), 2, size(TM,3));
    for u = 1:numel(ixA)
        spM = SM{ixA(u)};
        for tr = 1:size(TM,3)
            smA(u, 1, tr) = sum(spM>ST_(tr)-1.7 & spM<ST_(tr))./1.7;
            smA(u, 2, tr) = sum(spM>ST_(tr)+1 & spM<ST_(tr)+2.7)./1.7;
        end
    end    
    SM_A(s,:,:) = sum(smA.*abs(wA), 1) ./ sum(abs(wA));
    wSM_A(s,:,:) = sum((smA-mean(smA(:,2,:),[3])).*wA, 1);
    psmA = sum(smA.*wA, 1) ;
    
    ixO = Vect_ID{2,Ser(s)};
    wO = Vect_Saver_OtoA_raw{2,Ser(s)};
    bO = (Vect_Saver_OtoA_rawSpikes{2,Ser(s)}./(150.*2))';
    actO = iFR(ixO,:,:);
    Normal_O(s,:,:) = mean(actO,1);
    M_O(s,:,:) = sum(actO.*abs(wO), 1) ./ sum(abs(wO));
    projO = sum((actO-bO).*wO, 1) ;
    smO = NaN(numel(ixO), 2, size(TM,3));
    for u = 1:numel(ixO)
        spM = SM{ixO(u)};
        for tr = 1:size(TM,3)
            smO(u, 1, tr) = sum(spM>ST_(tr)-1.7 & spM<ST_(tr))./1.7;
            smO(u, 2, tr) = sum(spM>ST_(tr)+1-.275 & spM<ST_(tr)+2.7-.275)./1.7;
        end
    end
    SM_O(s,:,:) = sum(smO.*abs(wO), 1) ./ sum(abs(wO));
    wSM_O(s,:,:) = sum((smO-mean(smO(:,2,:), [3])).*wO, 1);
    psmO = sum(smO.*wO, 1) ;
    
    signer = sign(mean(psmA(1,2,:)-psmA(1,1,:), "all") + mean(psmO(1,2,:)-psmO(1,1,:), "all"));
    wSM_O(s,:,:) = signer.*wSM_O(s,:,:);
    wSM_A(s,:,:) = signer.*wSM_A(s,:,:);
    Mp_A(s,:,:) = signer.*projA;
    Mp_O(s,:,:) = signer.*projO;
    TM_(s,:,:) = TM(ixA(1),:,:);
end
fig = figure;
fig.Position = [810 844 560 287];
tiledlayout(2,2)
nexttile % FIGURE 4R
MirkoBerlin_AbsoluteDev(Mp_A, TM_, Events, Ser);
title("aPC CC proj.")
xlabel("Time (s)")
ylabel("Projection")
xlim([19, size(iFR,2)])
nexttile % FIGURE 4S
MirkoBerlinProjection(M_A, TM_, Events, Ser);
title("aPC CC FR")
xlabel("Time (s)")
ylabel("iFR (Hz)")
xlim([19, size(iFR,2)])
nexttile % FIGURE 4R
MirkoBerlin_AbsoluteDev(Mp_O, TM_, Events, Ser);
title("OT CC proj.")
xlabel("Time (s)")
ylabel("Projection")
xlim([19, size(iFR,2)])
nexttile % FIGURE 4S
MirkoBerlinProjection(M_O, TM_, Events, Ser);
xlabel("Time (s)")
ylabel("iFR (Hz)")
xlim([19, size(iFR,2)])
title("Tu CC FR")
sgtitle("Projections and absolute weight iFR, " + sum(Select) + " sessions with Tu->aPC")
%% LME for devaition from baseline 
% Statistical tests of FIGURE 4R 
wX_A_bl = [];
wX_A_cs = [];
wX_O_bl = [];
wX_O_cs = [];
Mish_ = [];
Sesh_ = [];
Type_ = [];
TypeB_ = [];
for s = 1:size(M_A,1)
    wX_A_bl = cat(1, wX_A_bl, squeeze(wSM_A(s,1,:)));
    wX_A_cs = cat(1, wX_A_cs, squeeze(wSM_A(s,2,:)));
    wX_O_bl = cat(1, wX_O_bl, squeeze(wSM_O(s,1,:)));
    wX_O_cs = cat(1, wX_O_cs, squeeze(wSM_O(s,2,:)));

    Mish_ = cat(1, Mish_, Mer(s).*ones(size(wSM_A,3), 1));
    Sesh_ = cat(1, Sesh_, s.*ones(size(wSM_A,3), 1));
    Type_ = cat(1, Type_, squeeze(TM_(s,2,:)));
    TypeB_ = cat(1, TypeB_, squeeze(TM_(s,3,:)));
end 

X_A = [];
X_O = [];
Sunquer = unique(Sesh_);
Tunquer = unique(Type_);
n = 1;
for s = 1:numel(Sunquer)
    for ty = 1:numel(Tunquer)
        ixer = find(Sesh_==Sunquer(s) & Type_==Tunquer(ty));
        Pointer = abs(mean(wX_A_cs(ixer) -  wX_A_bl(ixer)));
        X_A(n, 1) = Pointer;
        X_A(n,2) = Mish_(ixer(1));
        X_A(n,3) = Sesh_(ixer(1));
        X_A(n,4) = Type_(ixer(1));

        Pointer = abs(mean(wX_O_cs(ixer) -  wX_O_bl(ixer)));
        X_O(n, 1) = Pointer;
        X_O(n,2) = Mish_(ixer(1));
        X_O(n,3) = Sesh_(ixer(1));
        X_O(n,4) = Type_(ixer(1));
        
        n = n+1;
    end
end
ster = ['Difference ~ 1 + Type + (1 + Type|Mouse) + (1 + Type|Mouse:Session)']

X_A = array2table(X_A, "VariableNames", ["Difference", "Mouse", "Session", "Type"]);
X_A.Mouse = categorical(X_A.Mouse);
X_A.Session = categorical(X_A.Session);
X_A.Type = categorical(X_A.Type);
lme_A = fitlme(X_A, ster);
H = [0, -1, 1];
Covver = lme_A.CoefficientCovariance;
A_100_vs_50 = lme_A.Coefficients.Estimate(3) - lme_A.Coefficients.Estimate(2);
A_100_vs_50(2) = sqrt(H * Covver * H');
A_100_vs_50(3) = coefTest(lme_A, H);

X_O = array2table(X_O, "VariableNames", ["Difference", "Mouse", "Session", "Type"]);
X_O.Mouse = categorical(X_O.Mouse);
X_O.Session = categorical(X_O.Session);
X_O.Type = categorical(X_O.Type);
lme_O = fitlme(X_O, ster);
Covver = lme_O.CoefficientCovariance;
O_100_vs_50 = lme_O.Coefficients.Estimate(3) - lme_O.Coefficients.Estimate(2);
O_100_vs_50(2) = sqrt(H * Covver * H');
O_100_vs_50(3) = coefTest(lme_O, H);

"Two-tailed p-values, but effect size reported as indicated in 'Comparing'"
ster
Results = [["Comparing", "Region", "Effect size", "t-value", "p-value"];...
    ["CS100>CS0", "aPC", "" + lme_A.Coefficients.Estimate(3), lme_A.Coefficients.Estimate(3)./lme_A.Coefficients.SE(3), "" + lme_A.Coefficients.pValue(3)];...
    ["CS100>CS0", "Tu", "" + lme_O.Coefficients.Estimate(3), lme_O.Coefficients.Estimate(3)./lme_O.Coefficients.SE(3), "" + lme_O.Coefficients.pValue(3)];...
    ["CS50>CS0", "aPC", "" + lme_A.Coefficients.Estimate(2), lme_A.Coefficients.Estimate(2)./lme_A.Coefficients.SE(2), "" + lme_A.Coefficients.pValue(2)];...
    ["CS50>CS0", "Tu", "" + lme_O.Coefficients.Estimate(2), lme_O.Coefficients.Estimate(2)./lme_O.Coefficients.SE(2), "" + lme_O.Coefficients.pValue(2)];...
    ["CS100>CS50", "aPC", "" + A_100_vs_50(1),  A_100_vs_50(1)./A_100_vs_50(2), "" + A_100_vs_50(3)];...
    ["CS100>CS50", "Tu", "" + O_100_vs_50(1),  O_100_vs_50(1)./O_100_vs_50(2), "" + O_100_vs_50(3)]]

"DOF = " + lme_A.DFE


%% LME to see if aPC inhibited and Tu excited against baseline
% Statistical tests for FIGURE 4S
X_A_bl = [];
X_A_cs = [];
X_O_bl = [];
X_O_cs = [];
Mish_ = [];
Sesh_ = [];
Type_ = [];
TypeB_ = [];
for s = 1:size(M_A,1)
    X_A_bl = cat(1, X_A_bl, squeeze(SM_A(s,1,:)));
    X_A_cs = cat(1, X_A_cs, squeeze(SM_A(s,2,:)));
    X_O_bl = cat(1, X_O_bl, squeeze(SM_O(s,1,:)));
    X_O_cs = cat(1, X_O_cs, squeeze(SM_O(s,2,:)));

    Mish_ = cat(1, Mish_, Mer(s).*ones(size(SM_A,3), 1));
    Sesh_ = cat(1, Sesh_, s.*ones(size(SM_A,3), 1));
    Type_ = cat(1, Type_, squeeze(TM_(s,2,:)));
    TypeB_ = cat(1, TypeB_, squeeze(TM_(s,3,:)));
end 
Sunquer = categorical(unique(Sesh_));
ster = ['Difference ~ 1 + (1|Mouse) + (1|Mouse:Session) + (1|Session:Type)']
% ster = ['Difference ~ 1 + (1|Mouse) + (1|Mouse:Session)']

X_A = [X_A_bl, X_A_cs, Mish_, Sesh_, TypeB_];
X_A = array2table(X_A, "VariableNames", ["BL", "CS", "Mouse", "Session", "Type"]);
X_A.Mouse = categorical(X_A.Mouse);
X_A.Session = categorical(X_A.Session);
X_A.Type = categorical(X_A.Type);
X_A.Difference = X_A.CS - X_A.BL;
lme_A = fitlme(X_A, ster);


X_A_x0 = X_A; % We take all except CS0
X_A_x0(Type_==0,:) = []; 
X_A_x0.Difference = X_A_x0.CS - X_A_x0.BL;
lme_A_x0 = fitlme(X_A_x0, ster);
X_A_0 = X_A; % We take only CS0
X_A_0(Type_~=0,:) = []; 
X_A_0.Difference = X_A_0.CS - X_A_0.BL;
lme_A_0 = fitlme(X_A_0, ster);

X_O = [X_O_bl, X_O_cs, Mish_, Sesh_, TypeB_];
X_O = array2table(X_O, "VariableNames", ["BL", "CS", "Mouse", "Session", "Type"]);
X_O.Mouse = categorical(X_O.Mouse);
X_O.Session = categorical(X_O.Session);
X_O.Type = categorical(X_O.Type);
X_O.Difference = X_O.CS - X_O.BL;
lme_O = fitlme(X_O, ster);

X_O_x0 = X_O; % We take all except CS0
X_O_x0(Type_==0,:) = []; 
X_O_x0.Difference = X_O_x0.CS - X_O_x0.BL;
lme_O_x0 = fitlme(X_O_x0, ster);
X_O_0 = X_O; % We take only CS0
X_O_0(Type_~=0,:) = []; 
X_O_0.Difference = X_O_0.CS - X_O_0.BL;
lme_O_0 = fitlme(X_O_0, ster);


Results = [["Trials taken", "Region", "Effect size", "t-value", "p-value"];...
    ["CS0", "aPC", "" + lme_A_0.Coefficients.Estimate, lme_A_0.Coefficients.Estimate./lme_A_0.Coefficients.SE, "" + lme_A_0.Coefficients.pValue];...
    ["CS0", "Tu", "" + lme_O_0.Coefficients.Estimate, lme_O_0.Coefficients.Estimate./lme_O_0.Coefficients.SE, "" + lme_O_0.Coefficients.pValue];...
    ["CS50 and CS100", "aPC", "" + lme_A_x0.Coefficients.Estimate, lme_A_x0.Coefficients.Estimate./lme_A_x0.Coefficients.SE, "" + lme_A_x0.Coefficients.pValue];...
    ["CS50 and CS100", "Tu", "" + lme_O_x0.Coefficients.Estimate, lme_O_x0.Coefficients.Estimate./lme_O_x0.Coefficients.SE, "" + lme_O_x0.Coefficients.pValue]]

"DOF for CS50 and CS100 = " + lme_A_x0.DFE + ", DOF for CS0 = " + lme_A_0.DFE

%% Raster plots
% For some reason, I, Walter, took trials end-10 to end-1 in FIGURE 4T.
% I think it was rather an error in post-production. 
% It's an irrelevant errata.
figure
% !!! I PUT A PAUSE AT THE END OF THE LOOP!
for s = 65 % s = 1:88
    if ~Select(s); continue; end
    OT = find(Units.Name==Sessions(s) & Units.Region==2);
    Beit = SM(OT);  
    APC = find(Units.Name==Sessions(s) & Units.Region==1);
    Aleph = SM(APC); 

    ST_ = TM(OT(1),1,:);
    Stimuli_ = TM(OT(1),2,:);
    Trials = sum(~isnan(ST_(1,1,:)));
    ST_ = squeeze(ST_(:, :, 1:Trials))';
    Stimuli_ = squeeze(Stimuli_(:, :, 1:Trials))';

    Doer = find(Stimuli_==100); 
    Doer = Doer(end-10:end-1); % Take only the last 10 trials of CS100
    % I accidentally left out the very last trial (I did this mistake
    % probably in post-production). So here I also leave the last trial out
    % so that the same FIGURE 4T is produced. 

    bO = abs(Vect_Saver_OtoA{2,s}); % I use the weights from a CCA where the units
    % were z-scored so that I know their real contribution (as a unit with
    % few spikes will in general be weighted more heavily, without it being
    % more significant).
    [~, OT_unit] = max(bO);
    bA = abs(Vect_Saver_OtoA{1,s});
    [~, aPC_unit] = max(bA);
    for do = 1:numel(Doer)
        Tu_spikes =  Beit{OT_unit}-ST_(Doer(do));
        Tu_spikes(Tu_spikes<-3 | Tu_spikes>5) = [];
        scatter(Tu_spikes,  +(do-1) + ones(1,numel(Tu_spikes)), 100, 'Marker', '|', 'MarkerEdgeColor', "b", 'MarkerFaceColor', "b")
        hold on
        aPC_spikes =  Aleph{aPC_unit}-ST_(Doer(do));
        aPC_spikes(aPC_spikes<-3 | aPC_spikes>5) = [];
        scatter(aPC_spikes, +(do-1) + ones(1,numel(aPC_spikes)), 100, 'Marker', '|', 'MarkerEdgeColor', "r", 'MarkerFaceColor', "r")
    end
    xline(0, "k")
    xline(1, '--k')        
    xline(2.7, "k")
    Yer = ylim;
    % ylim([Yer(1), 1.62])
    xlim([-3, 5])
    title("Mouse " + Mauser(s) + ", s=" + s)
    pause
    clf
end
