function Linearity = Cal_Linearity(Seg)
% calculate linearity of each segment
% input: cell array containing each segments

% Di Wang, di.wang@aalto.fi
%%
Linearity = zeros(length(Seg),1);
for i = 1:length(Seg)
    P = Seg{i};
    [m,~] = size(P);
    if m>=5
        P = P-ones(m,1)*(sum(P,1)/m);
        C = P.'*P./(m-1);
        [~, D] = eig(C);
        
        epsilon_to_add = 1e-8;
        EVs = [D(3,3) D(2,2) D(1,1)];
        if EVs(3) <= 0; EVs(3) = epsilon_to_add;
            if EVs(2) <= 0; EVs(2) = epsilon_to_add;
                if EVs(1) <= 0; EVs(1) = epsilon_to_add; end
            end
        end
        sum_EVs = EVs(1) + EVs(2) + EVs(3);
        % normalization of eigenvalues
        EVs(:,1) = EVs(:,1) ./ sum_EVs;
        EVs(:,2) = EVs(:,2) ./ sum_EVs;
        EVs(:,3) = EVs(:,3) ./ sum_EVs;
        
        Linearity(i) = ( EVs(:,1) - EVs(:,2) ) ./ EVs(:,1);
    end
end

end