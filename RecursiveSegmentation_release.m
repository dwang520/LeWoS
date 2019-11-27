function [BiLabel, BiLabel_Regu] = RecursiveSegmentation_release(points,ft_threshold,paral,plot)
% points: nx3
% ft_threshold: threshold
% paral: if shut down parallel pool after segmentation (1 or other)
% plot: if plot results in the end (1 or other)

% BiLabel: point label without regularization
% BiLabel_Regu: point label with regularization

% Di Wang, di.wang@aalto.fi
%% 1 . ///////// Iterative Segmentation starts here////////////////////////////

% Calculate normal vector
normals = pcnormals(pointCloud(points(:,1:3)),10);

% graph based region growing
% 10 neighbors
k = 10;
Label = GraphRG(points, normals(:,3), k, ft_threshold);

% convert label to individual segments (Seg, cell)
t = accumarray(Label,[1:length(Label)]',[],@(x) {x});
Seg = cellfun(@(x) points(x,:),t,'UniformOutput',0);

% number of points of each segment
lb = cellfun(@(x) size(x,1),Seg);
% those segments with less than 10 points do not need further processing
Seg_reserve = Seg(lb<=10);
% these segments needs further segmentation
Seg_processing = Seg(lb>10);
clear Seg t lb Label normals

%% recursive segmentation
% segment each segments iteratively until it doesnt change anymore.
% again, after each segmentation event, those segments with less than 10
% points do not need further processing
% also set the maximum ieteration to be 10, because after 10 iterations,
% the change would be minimal, thus no further segmentation is needed.
for ii = 1:inf
    
    TMP = cell(length(Seg_processing),1);
    indx = false(length(Seg_processing),1);
    parfor i = 1:length(Seg_processing)
        points_n = Seg_processing{i};
        normals = pcnormals(pointCloud(points_n(:,1:3)),10);
        Label = GraphRG(points_n, normals(:,3), k, ft_threshold);
        
        if max(Label)==1
            indx(i) = true;
        else
            t = accumarray(Label,[1:length(Label)]',[],@(x) {x});
            Seg = cellfun(@(x) points_n(x,:),t,'UniformOutput',0);
            
            TMP{i} = Seg;
        end
    end
    
    Seg = cat(1, TMP{:});
    
    unchange = Seg_processing(indx);
    
    if sum(indx) == length(Seg_processing) || ii == 10
        Seg_final = [Seg;Seg_reserve;unchange];
        break
    else
        lb = cellfun(@(x) size(x,1),Seg);
        
        Seg_processing = Seg(lb>10);
        
        Seg_reserve = [Seg_reserve;unchange;Seg(lb<=10)];
    end
end

clear Seg_reserve unchange Seg_processing Seg

%% The final segmentation results after recursive segmentation is stored in Seg_final (cell)

%% visualize segmentation results
% cmap = hsv(length(Seg_final));
% pz = randperm(size(cmap,1),size(cmap,1));
% cmap = cmap(pz,:);
% col = cell(length(Seg_final),1);
% for i =1:length(Seg_final)
%     ww = Seg_final{i};
%     col(i) = {repmat(cmap(i,:),size(ww,1),1)};
% end
% figure;pcshow(cell2mat(Seg_final),cell2mat(col));grid off;
% clear cmap pz col

%% 
%further split each segment into individual branches, because z-value of
%normal vectors itself is not enough to segment points into branches. In
%some case, it forms a large co-planar segment. We use the method from
%TreeQSM to further split segment. 
%https://github.com/InverseTampere/TreeQSM
%also
%https://github.com/InverseTampere/Vessel-Segmentation

% these parameters are required by treeQSM, not important
Inputs.PatchDiam1 = 0.1; % Patch size of the first uniform-size cover
Inputs.PatchDiam2Min = 0.03; % Minimum patch size of the cover sets in the second cover
Inputs.PatchDiam2Max = 0.08; % Maximum cover set size in the stem's base in the second cover
Inputs.lcyl = 3; % Relative (length/radius) length of the cylinders
Inputs.FilRad = 3; % Relative radius for outlier point filtering
Inputs.BallRad1 = Inputs.PatchDiam1+0.02; % Ball radius in the first uniform-size cover generation
Inputs.BallRad2 = Inputs.PatchDiam2Max+0.01; % Maximum ball radius in the second cover generation
Inputs.nmin1 = 3; % Minimum number of points in BallRad1-balls, generally good value is 3
Inputs.nmin2 = 1; % Minimum number of points in BallRad2-balls, generally good value is 1
Inputs.OnlyTree = 1; % If 1, point cloud contains points only from the tree

%% slipt segments
% addpath('./TreeQSM_src')
% linearity = Cal_Linearity(Seg_final);
Seg_post = cell(length(Seg_final),1);
parfor i = 1:length(Seg_final)
    
    pts = Seg_final{i};
    if size(pts,1)>100 && (max(pts(:,3)) - min(pts(:,3)))>1
        % Generate cover sets
        cover1 = cover_sets(pts,Inputs);
        if length(cover1.ball) > 2
            % find a base cover
            Base = find(pts(cover1.center,3) == min(pts(cover1.center,3)));
            Forb = false(length(cover1.center),1);
            % do the segmentation
            segment1 = segments(cover1,Base,Forb);
            Seg_tmp = cell(length(segment1.segments),1);
            for j = 1:length(segment1.segments)
                ids = cell2mat(cover1.ball(cell2mat(segment1.segments{j})));
                Seg_tmp{j} = pts(ids,:);
            end
            Seg_post{i} = Seg_tmp;
        else
            Seg_post{i} = {pts};
        end
    else
        Seg_post{i} = {pts};
    end
end
Seg_final= cat(1, Seg_post{:});
clear Seg_post

%% Seg_final is the final segmentaion results after all processing !!

%% shut down parallel pool to save memory
if paral == 1
    poolobj = gcp('nocreate');
    delete(poolobj);
end

%% ///////// Segmentation is done above////////////////////////////
%% 2. ///////// below start find branch segments/////////////////////

% two thresholds are needed to identify those segmentation belonging to
% branches, Linearity threshold and size threshold. Instead of specifying
% hard thresholds, we test a range of values and count for the frequency of
% a point being identified as wood. The output of this step is a
% probability distribution.

% calculate linearity of each segment
linearity = Cal_Linearity(Seg_final);
% calculate size of each segment
sl = cellfun(@(x)size(x,1),Seg_final);

% upwrap segments to points, so we can operate on point level
LL = cell(length(Seg_final),1);
SL = cell(length(Seg_final),1);
for i = 1:length(Seg_final)
    P = Seg_final{i};
    
    LL{i} = repmat(linearity(i),size(P,1),1);
    SL{i} = repmat(sl(i),size(P,1),1);
end
LiPts = cell2mat(LL);
SzPts = cell2mat(SL);
Pts = cell2mat(Seg_final);

% test a range of thresholds
Lthres_list = 0.70:0.02:0.95;
Sthres_list = 10:2:50;
% all combinations of two thresholds
allc = combvec(Lthres_list,Sthres_list)';
% 
Freq = zeros(size(Pts,1),1);
for i = 1:size(allc,1)
    % find wood points based on two thresholds
    ia = LiPts >= allc(i,1) & SzPts >= allc(i,2);
    % count the frequency of being identified as wood
    Freq = Freq + ia;
end

%% Probability that a point is wood !!!
Pli = Freq/size(allc,1);

%% ///////// Probability estimation is done above////////////////////////////
%% 3. ///////// below start regularization (label smoothing)/////////////////////

% we use the ALPHA-EXPANSION method from
% https://github.com/loicland/point-cloud-regularization
% (it has a native C++ implementaion I think)
% to regularize point labels to make the final prediction spatially smooth.
% The method is also based on graph energy optimization, and requires a
% probability as input. Our above method is naturally suitble for this.

% addpath('./GCMex')
% build adjacent graph (similar to the one in "GraphRG")
graph = build_graph_structure(Pts,20,0);
% initial class probability from our "Pli"
initial_classif = single([Pli,1-Pli]);
% alpha expansion method, output is the regularized label per point
[l_lin_potts, ~, ~, ~] = alpha_expansion(initial_classif, graph, 0, 1, 5);
% we also record the label without regularization (directly from "Pli")
[~, l_baseline] = max(initial_classif,[],2);

%% ///////// regularization is done above////////////////////////////
%% 4. ///////// below prepare final results/////////////////////


%% restore original order (the original order was lost during wrapping labels to segments)
idx = knnsearch(Pts,points);

% wood label ->1 , leaf label -> 0
% BiLabel refers to point label without regularization !!
BiLabel = l_baseline(idx);
BiLabel(BiLabel~=1) = 0;
% BiLabel_Regu refers to point label with regularization !!
BiLabel_Regu = l_lin_potts(idx);
BiLabel_Regu(BiLabel_Regu~=1) = 0;

%% if visualize
if plot == 1
    wood = Pts(l_baseline==1,:);
    leaf = Pts(l_baseline~=1,:);
    
    wood2 = Pts(l_lin_potts==1,:);
    leaf2 = Pts(l_lin_potts~=1,:);
    
    figure('units','normalized','outerposition',[0 0 1 1]);
    subplot(1,2,1)
    pcshow(wood, repmat([0.4471, 0.3216, 0.1647],size(wood,1),1));
    hold on
    pcshow(leaf, repmat([0.2667, 0.5686, 0.1961],size(leaf,1),1));
    hold off
    grid off
    xlabel('X(m)');ylabel('Y(m)');zlabel('Z(m)');
    title('No Regularization')
    subplot(1,2,2)
    pcshow(wood2, repmat([0.4471, 0.3216, 0.1647],size(wood2,1),1));
    hold on
    pcshow(leaf2, repmat([0.2667, 0.5686, 0.1961],size(leaf2,1),1));
    hold off
    grid off
    xlabel('X(m)');ylabel('Y(m)');zlabel('Z(m)');
    title('With Regularization')
end
end
