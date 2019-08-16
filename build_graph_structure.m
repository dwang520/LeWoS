function graph = build_graph_structure(pts, k, edge_weight_mode)
%compute the knn structure
%INPUT
%pts: nx3 point cloud 
%int k = number of nodes (default is 10)
%single edge_weight_mode = weighting mode of the edges
%   c = 0 : constant weight (default)
%   c > 0 : linear weight w = 1/(d/d0 + c) 
%   c < 0 : exponential weightw = exp(-d/(c * d0))
%OUTPUT
%struct graph =  a structure with the following fields:
%single matrix XYZ : coordinates of each point
%int32 vectors source, target: index of the vertices constituting the
%edges
%single vector edge_weight: the edge of the  
if (nargin < 2)
    k = 10;
end
if (nargin < 3)
    edge_weight_mode = 0;
end
graph= struct;
graph.XYZ = pts;
n_point = size(graph.XYZ,1);
%---compute full adjacency graph-------------------------------------------
[neighbors,distance] = knnsearch(graph.XYZ,graph.XYZ,'K', k+1);
neighbors = neighbors(:,2:end);
distance  = distance(:,2:end);
d0     = mean(distance(:));
source      = reshape(repmat(1:n_point, [k 1]), [1 (k * n_point)])';
target      = reshape(neighbors', [1 (k * n_point)])';
%---edge_weight computation------------------------------------------------
edge_weight = ones(size(distance));
if (edge_weight_mode>0)
    edge_weight = 1./(distance / d0 + edge_weight_mode);
elseif (edge_weight_mode<0)
    edge_weight = exp(distance / (d0 * edge_weight_mode));
end
edge_weight = reshape(edge_weight, [1 (k * n_point)])';
%---pruning----------------------------------------------------------------
dt = mean(distance,2) + std(distance,0,2);
prune = bsxfun(@gt,distance',dt')';
pruned      = reshape(prune', [1 (k * n_point)])';
%---remove self edges and pruned edges-------------------------------------
selfedge = source==target;
to_remove = selfedge + pruned;
source      = source(~to_remove);
target      = target(~to_remove);
edge_weight = edge_weight(~to_remove);
%% avoid using unique
Edge  = [[source;target],[target;source]];
Weight = [edge_weight;edge_weight]; 
adj = sparse(Edge(:,1),Edge(:,2),Weight,size(pts,1),size(pts,1));
[source,target,edges_weight] = find(adj);
source = source-1;
target = target-1;
%---filling the structure -------------------------------------------------
graph.source      = int32(source);
graph.target      = int32(target);
graph.edge_weight = single(edges_weight);
