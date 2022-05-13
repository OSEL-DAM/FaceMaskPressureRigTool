function pSpike_i = pSpike(P_data)
%
% This code is available under public domain, free of all copyright, and
% may be freely reproduced, distributed, transmitted, modified, built upon,
% or otherwise used by anyone for any lawful purpose. However, this license
% does not govern the software needed to run this script and dependent
% functions and are governed under a sperate license. This code, and its
% dependent functions are listed “AS IS” and does not come with any
% expressed or implied warranty. The authors of this code and its dependent
% functions are not liable for any damages arising from the use of this
% code and its dependent functions. The use of this code, its dependent
% functions, or the software required to run it does not constitute an
% endorsement from the U.S. Food and Drug Administration or U.S. Department
% of Health and Human Services.
%
% Written By: Alexander Herman
% U.S. Food and Drug Administration
% Revised: 04-Jun-2021
%
% PSPIKE is a function that detects a sudden change in a 1D vector signal
% (Pressure) and outputs its index. This is done by picking a random point
% along the vector finding the cumulative variances on both side of the
% point, multiplying it by the index of the random point from each end,
% adding them together. The point with the smallest sum represents the
% point where the variances on both sides are least fluctuating and thus
% results in the most significant point where the signal changes. This
% algorithm is similar to the one shown in the FINDCHANGEPTS documentation.
% That in turn references three other papers on the subject (See References
% Below).
%
% --- References ---
%
% [1]	"Find abrupt changes in signal - MATLAB findchangepts",
% Mathworks.com, 2016. [Online]. Available:
% https://www.mathworks.com/help/signal/ref/findchangepts.html#d123e60404.
% [Accessed: 04-Jun-2021].
%
% [2]	P. P. Pebay, "Formulas for robust, one-pass parallel computation of
% covariances and arbitrary-order statistical moments,"; Sandia National
% Laboratories (SNL), Albuquerque, NM, and Livermore, CA (United States),
% SAND2008-6212; TRN: US201201%%57 United States 10.2172/1028931 TRN:
% US201201%%57 SNL English, 2008. [Online]. Available:
% https://www.osti.gov/servlets/purl/1028931
%
% [3]	T. F. Chan, G. H. Golub, and R. J. LeVeque, "Algorithms for
% Computing the Sample Variance: Analysis and Recommendations," The
% American Statistician, vol. 37, no. 3, pp. 242-247, 1983, doi:
% 10.2307/2683386.
%
% [4]	R. Killick, P. Fearnhead, and I. A. Eckley, "Optimal Detection of
% Changepoints With a Linear Computational Cost," Journal of the American
% Statistical Association, vol. 107, no. 500, pp. 1590-1598, 2012.
% [Online]. Available: http://www.jstor.org/stable/23427357.
%
% [5]	J. Muñoz and C. Luengo, "Which function allow me to calculate
% cumulative variance over a vector?", Stack Overflow, 2019. [Online].
% Available: https://stackoverflow.com/questions/58343348/. [Accessed:
% 04-Jun-2021].


%% Initilizes Array and Constants
[v_sum,v1,v2]=deal(zeros(1,numel(P_data)));
N=numel(P_data);
%% Calculates Cumulative Variances & Variances Sums
for idx=1:N
    if idx~=1
        % Cumulative Variances Before the Random Point
        v1(idx)=(idx-1)*var(P_data(1:idx-1));
    end
    % Cumulative Variances After the Random Point
    v2(idx)=(N-idx+1)*var(P_data(idx:N));
    % Sums the Variances Before and After the Random Point
    v_sum(idx)=v1(idx)+v2(idx);
end
%% Find the Minimum Variances Sums Across All Random Points
[~,pSpike_i]=min(v_sum);

end