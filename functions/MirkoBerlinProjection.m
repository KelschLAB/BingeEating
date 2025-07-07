function MirkoBerlinProjection(M, TM, Events, Mauser)
% MirkoColor = {[1, 0, 1], [0, 0, 1], [0.9804, 0.3843, 0.1255],[0.0039, 0.3216, 0.0863]};
MirkoColor = {[0, 0.6, 0.1], [0, 0, 1], [1.000, .3, 0],[.4, 0.2, 0.2]};
First = 1:size(M,2); 

Munquer = unique(Mauser);

Resper = NaN(4, size(M,2), numel(Munquer), 2);


for m = 1:numel(Munquer)
    M_ = M(Mauser==Munquer(m), :, :);
    TM_ = TM(Mauser==Munquer(m), :, :);
    [Neurons, Bins, keep] = size(M_);
    x0 = [];
    x100 = [];
    x50R = [];
    x50N = [];
    for u = 1:size(TM_,1)
        x0 = cat(1, x0, TM_(u,3,:)==8);
        x100 = cat(1, x100, TM_(u,3,:)==5);
        x50R = cat(1, x50R, TM_(u,3,:)==10);
        x50N = cat(1, x50N, TM_(u,3,:)==11);
    end
    x0 = logical(x0);
    x100 = logical(x100);
    x50R = logical(x50R);
    x50N = logical(x50N);

    % x100
    Ma = NaN(Neurons, Bins, keep);
    for u = 1:Neurons
        temp = M_(u, :, squeeze(x100(u, 1, :)));
        Ma(u, :, 1:size(temp, 3)) = temp;
    end
    Avg = squeeze(mean(Ma, [1, 3], "omitnan"));
    SEM = squeeze(StdError(squeeze(mean(Ma, 1, "omitnan"))')); % check for the right axis of Std
%     boundedline(First, Avg, SEM, 'LineWidth', 2, 'alpha', 'Color', MirkoColor{1})
    Resper(1, :, m, 1) = Avg;
    Resper(1, :, m, 2) = SEM;
    % x0
    Ma = NaN(Neurons, Bins, keep);
    for u = 1:Neurons
        temp = M_(u, :, squeeze(x0(u, 1, :)));
        Ma(u, :, 1:size(temp, 3)) = temp;
    end
    Avg = squeeze(mean(Ma, [1, 3], "omitnan"));
    SEM = squeeze(StdError(squeeze(mean(Ma, 1, "omitnan"))')); % check for the right axis of Std
%     boundedline(First, Avg, SEM, 'LineWidth', 2, 'alpha', 'Color', MirkoColor{2})
    Resper(2, :, m, 1) = Avg;
    Resper(2, :, m, 2) = SEM;

    % x50R
    Ma = NaN(Neurons, Bins, keep);
    for u = 1:Neurons
        temp = M_(u, :, squeeze(x50R(u, 1, :)));
        Ma(u, :, 1:size(temp, 3)) = temp;
    end
    Avg = squeeze(mean(Ma, [1, 3], "omitnan"));
    SEM = squeeze(StdError(squeeze(mean(Ma, 1, "omitnan"))')); % check for the right axis of Std
%     boundedline(First, Avg, SEM, 'LineWidth', 2, 'alpha', 'Color', MirkoColor{3})
    Resper(3, :, m, 1) = Avg;
    Resper(3, :, m, 2) = SEM;
    % x50N
    Ma = NaN(Neurons, Bins, keep);
    for u = 1:Neurons
        temp = M_(u, :, squeeze(x50N(u, 1, :)));
        Ma(u, :, 1:size(temp, 3)) = temp;
    end
    Avg = squeeze(mean(Ma, [1, 3], "omitnan"));
    SEM = squeeze(StdError(squeeze(mean(Ma, 1, "omitnan"))')); % check for the right axis of Std
%     boundedline(First, Avg, SEM, 'LineWidth', 2, 'alpha', 'Color', MirkoColor{4})
    Resper(4, :, m, 1) = Avg;
    Resper(4, :, m, 2) = SEM;
end

% Weights = 1./Resper(:, :, :, 2).^2;
Avg = mean(Resper(:,:,:,1), 3);
SEM = std(Resper(:,:,:,1), 0, 3)./sqrt(size(Resper,3));
for ty = 1:4
    boundedline(First, Avg(ty,:), SEM(ty,:), 'LineWidth', 2, 'alpha', 'Color', MirkoColor{ty})
end


    xlim([1, size(M_,2)])
    xline(Events(1))
    xline(Events(1)+10, '--')
    xline(Events(2))
    xticks([Events(1)-40:10:Events(3)])
    xticklabels([-4:11])
    hold off
end

function SEM = StdError(Data)
Valids = ~isnan(Data); Valids = sum(Valids, 1);
SEM = std(Data, 1, 1, "omitnan")./sqrt(Valids);
end
