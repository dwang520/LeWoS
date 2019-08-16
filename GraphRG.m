function Label = GraphRG(X, feature, k, ft_threshold)

% graph based region growing 
%(clustering using graph -> connected components in graph)

% X: nx3 points
% feature: nx1 feature vector (z value of normal vector)
% k: number of neighbors used for graph built
% nz_threshold: feature threshold
% output Label 1 to n defines class label of each point

% Di Wang, di.wang@aalto.fi
%%
n_point = size(X,1);
%---compute full adjacency graph-------------------------------------------
[neighbors,distance] = knnsearch(X,X,'K', k+1);
% remove point itself
neighbors = neighbors(:,2:end);
distance  = distance(:,2:end);
% convert to nx2 matrix
source = reshape(repmat(1:n_point, [k 1]), [1 (k * n_point)])';
target = reshape(neighbors', [1 (k * n_point)])';

%% ---pruning----------------------------------------------------------------
% for each point, remove its neighbors that farther than (mean+std)
dt = mean(distance,2) + std(distance,0,2);
prune = bsxfun(@gt,distance',dt')';
pruned = reshape(prune', [1 (k * n_point)])';

% define the farthest distance maxd, remove all neighbors farther than it
maxd = mean(distance(:,end)) + std(distance(:,end));
prune2 = distance > maxd;
pruned2 = reshape(prune2', [1 (k * n_point)])';

%% ---remove self edges and pruned edges-------------------------------------
% self edges
selfedge = source==target;
% all edges to be removed
to_remove = selfedge + pruned + pruned2;
% remove them
source = source(~to_remove);
target = target(~to_remove);

%% test edges again feature threshold
dv = nan(length(source),1);
for j = 1:length(source)
    dv(j) = abs(abs(feature(source(j))) - abs(feature(target(j))));
end
% graph edges
source = source(dv<=ft_threshold,:);
target = target(dv<=ft_threshold,:);

%% flip edges
Edge = [source,target];
Edge2 = [Edge(:,2),Edge(:,1)];
% final graph edges
Edge = [Edge;Edge2];

%% construct a graph based on edge list
adj = sparse(Edge(:,1),Edge(:,2),ones(size(Edge,1),1),size(X,1),size(X,1));
Gp = graph(adj);

%% find connected components of the graph
Label = conncomp(Gp);
Label = Label';

end