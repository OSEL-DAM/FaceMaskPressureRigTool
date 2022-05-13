function pCell2CSV(pCell_in,FN,num_per)
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
% PCELL2CSV is a function that saves a cell array to a CSV file. This
% function uses FPRINTF to output a CSV file. This was used to over the
% newer WRITECELL for compatibility with older versions of MATLAB.
% 
%   Input Parameters:
%
%   PCELL_IN - Cell Array to be saved as a CSV File
%
%   FN - Character array of the file name of the CSV to be outputted less
%   the file extention
%
%   num_per - Precision of the number to output in the output table
%

%% Transposes Input Table
% This is needed because of the difference between MATLAB linear indexing
% scheme (Top Down) verses how FPRINTF writes to a file (Left to Right)
pCell_in = pCell_in';

%% Converts numerical values in the cell to a character array
pCell_num = cellfun(@isnumeric,pCell_in);
pCell_in(pCell_num) = cellstr(num2str([pCell_in{pCell_num}]',num_per));

%% Generates Format String for FPRINTF
[pCell_r,pCell_c] = size(pCell_in);
pCell_fs = repmat([repmat('%s,',1,pCell_r-1),'%s\n'],1,pCell_c);

%% File Creation
% Creates the output file, writes to it according to the format string then
% closes it.
pCell_out = fopen([FN,'.csv'],'w');
fprintf(pCell_out,pCell_fs,pCell_in{:});
fclose(pCell_out);

end

