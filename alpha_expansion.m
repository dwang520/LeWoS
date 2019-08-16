function [assignment, T, ENERGY, ENERGYAFTER] = alpha_expansion(initial_p, graph, fidelity, lambda, maxIte)
%alpha expansion algorithm to solve penalization by the potts penalty
%INPUT
%inital_labeling = classification to regularize
%graph  = the adjacency structure
%fidelity = which fidelity fucntion to use (default = 0)
%	0 : linear
%	1 : quadratic  
%	2 : KL with 0.05 uniform smoothing
%	3 : loglinear with 0.05 uniform smoothing
%lambda      : regularization strength (default = 1)
%maxIte      : maximum number of alpha expansion cycle (default = 5)
%benchMarking: if true will return the energy and time for the algorithm
%            : stopped after 1 ... maxIte iteration, starting from zero 
%              each time
%OUTPUT
%assignment = the regularized labeling
%T          =  computing time
%loic landrieu 2016
%
%When using this method you must cite:
%
%Efficient Approximate Energy Minimization via Graph Cuts 
%		Yuri Boykov, Olga Veksler, Ramin Zabih, 
%       IEEE transactions on PAMI, vol. 20, no. 12, p. 1222-1239
%       , November 2001. 
%
%What Energy Functions can be Minimized via Graph Cuts?
%	    Vladimir Kolmogorov and Ramin Zabih. 
%	    To appear in IEEE Transactions on Pattern Analysis and Machine
%       Intelligence (PAMI). 
%	    Earlier version appeared in European Conference on Computer Vision
%       (ECCV), May 2002. 
%
%An Experimental Comparison of Min-Cut/Max-Flow Algorithms
%	    for Energy Minimization in Vision.
%	    Yuri Boykov and Vladimir Kolmogorov.
%		In IEEE Transactions on Pattern Analysis and Machine
%       Intelligence (PAMI), 
%	    September 2004

% initial_p=initial_classif;

lambda=1;
if (nargin < 3)
    fidelity = 0;
end
if (nargin < 4)
    lambda = 1;
end
if (nargin < 5)
    maxIte = 30;
end
smoothing= 0.05; %the smoothing paremeter
nbNode  = max(size(initial_p,1));
nClasses    = size(initial_p,2);
pairwise     = sparse(double([graph.source]+1), double([graph.target]+1) ...
    ,double(graph.edge_weight * lambda)); 
mpairwise=size(pairwise,1);
npairwise=size(pairwise,2);
if mpairwise ~= nbNode  | npairwise ~= nbNode
    dm=nbNode-mpairwise;
    dn=nbNode-npairwise;
    pairwise=[pairwise,zeros(mpairwise,dn)];
    pairwise=[pairwise;zeros(dm,size(pairwise,2))];
end
switch fidelity
    case 0
        unary      = squeeze(sum(...
                     ((repmat(1:nClasses, [size(initial_p,1) 1 nClasses])...
                   ==  permute(repmat(1:nClasses, [size(initial_p,1) 1 nClasses]), [1 3 2])) ...
                   - repmat(initial_p, [1 1 size(initial_p,2)])).^2,2));
    case 1
        unary      = -initial_p;
    case 2
        smoothObs  = repmat(smoothing/ nClasses + (1 - smoothing) * initial_p ...
                    , [1 1 nClasses]);
        smoothAssi = smoothing / nClasses + (1 - smoothing) * ...
                    (repmat(1:nClasses, [nbNode 1 nClasses])...
                   ==  permute(repmat(1:nClasses, [nbNode 1 nClasses]), [1 3 2]));
        unary      = -squeeze(sum(smoothObs .* ( log(smoothAssi)),2));
   case 3
        smoothObs  = smoothing / nClasses + (1 - smoothing) * initial_p;
        unary      = -log(smoothObs); 
end
%normalization
unary = bsxfun(@minus, unary, min(unary,[],2));
unary = unary ./ mean(unary(:)); %normalization

labelcost  = single(1*(ones(nClasses)-eye(nClasses)));
[dump, labelInit] = max(initial_p,[],2);
labelInit = labelInit - 1;
clear('I', 'J', 'V','dump')
tic;
% [assignment] = GCMex(double(labelInit), (unary'), (pairwise)...
%                       , single(labelcost),true,int32(maxIte));
[assignment, ENERGY ENERGYAFTER] = GCMex(double(labelInit), (unary'), (pairwise)...
                      , single(labelcost),true);

                  assignment = assignment +1;
T = toc;