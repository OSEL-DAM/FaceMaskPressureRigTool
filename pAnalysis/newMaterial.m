function newname = newMaterial(oldname,std_name)
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
% Revised: 28-May-2021
%
% NEWMATERIAL compares the material name (OLDNAME) against a lookup table
% (OLDNEWNAMES) and either returned the standardized name from the table in
% the form of a nx2 cell array with charater vectors or returns the old
% name based off a input flag (STD_NAME).
% 
% --- Lookup Table Format ---
% OLDNEWNAMES: Column 1: Old Name, Column 2: New to Replace Old Name in
% Corresponding Row.
%
% A standardized name will be returned if STD_NAME is true and there is a
% match of the OLDNAME in column 1 in OLDNEWNAMES. The standardized name
% will be in column 2 of the same row where the OLDNAME is found in column
% 1 of OLDNEWNAMES. If no match if found or STD_NAME flag is false then the
% OLDNAME is returned.

%% Initalizses the Lookup Table
oldnewnames = {'1860 N95 (25mm & 2.2LPM)','1860 N95';...
    '1860 N95 (25mm)','1860 N95';'1860 N95 (2.2LPM)','1860 N95'};

%% Compares The Old Name Against the Look Up Table
name_bools = strcmp(oldnewnames(:,1),oldname);

if ~std_name || (~any(name_bools) && std_name)
    % If standard name flag is disabled or any name was not found in OLDNEWNAMES
    % lookup array ans standard name flag is enabled, then the old name is retured
    newname = oldname;
else
    % Returned Name is New Name from OLDNEWNAMES
    newname = oldnewnames(name_bools,2);
    newname=[newname{:}];
end
end