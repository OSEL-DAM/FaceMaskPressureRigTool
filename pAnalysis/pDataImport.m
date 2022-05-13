function [P_data]=pDataImport(filename)
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
% PDATAIMPORT Import data from a text file outputted from our pressure
% transducer logger program. It reads data from text file FILENAME and
% output the data from the file in a structure. This fuction is based on
% the text file output from presslog.py reads all of the different data
% fields from that text file.

%% Initialize Variables.

% Offsets
OS_del={'  ','|'};
OS_sRow=5;
OS_eRow=9;
OS_FS='%s%s%s%[^\n\r]';

% Data
D_del='\t';
D_sRow=10;
D_eRow=inf;
D_FS='%f%f%f%f%f%f%f%f%f%f%[^\n\r]';

%% Scans Text Document

% Open the text file.
fileID=fopen(filename,'r');

% Skips First Line
textscan(fileID,'%[^\n\r]',1,'ReturnOnError',false);

% Imports Date & Time
dt=textscan(fileID,'%*[^:]%*[:]%[^\n\r]',1,'ReturnOnError',false); 
P_data_c{1}=strrep(dt{:}{:},'_','-');
P_field_c{1}='DateTime';

% Imports Sample Name, ADS, and Frequency Infomation
f_set=textscan(fileID,'%s',8,'Delimiter',{' =',','},'ReturnOnError',false);
f_set=reshape(f_set{1},2,[]);
f_set(1,:)=strrep(f_set(1,:),'Filename','Material');
f_set(1,:)=strrep(f_set(1,:),' ','_');
f_set(2,:)=strrep(f_set(2,:),'.txt','');
f_set(2,:)=strrep(f_set(2,:),' hz','');
f_set(2,:)=strrep(f_set(2,:),' s','');
f_set(2,2:end)=num2cell(str2double(f_set(2,2:end)));
P_field_c=[P_field_c;f_set(1,:)'];
P_data_c=[P_data_c;f_set(2,:)'];

% Imports Offset Data
OS_array=textscan(fileID,OS_FS,OS_eRow(1)-OS_sRow(1)+1,'Delimiter', OS_del,'MultipleDelimsAsOne',true,'ReturnOnError',false);
OS_array=[OS_array{:,1:end-1}];
OS_array(1,:)=strrep(OS_array(1,:),'-','#_');
OS_array(2:end,1)=strrep(OS_array(2:end,1),'A','');
OS_F1=repmat(OS_array(2:end,1),size(OS_array,2)-1,1);
OS_F2=reshape(repmat(OS_array(1,2:end),size(OS_array,1)-1,1),[],1);
P_field_c=[P_field_c;strrep(OS_F2,'#',OS_F1)];
P_data_c=[P_data_c;num2cell(str2double(reshape(OS_array(2:end,2:end),[],1)))];

% Imports Headers
headers=textscan(fileID,'%s',10,'Delimiter','\t');
headers=strrep(headers{1},'#','Num')';
headers=strrep(headers,'time(s)','tElasp_s'); %')',''

% Extract QOI Units from Headers
c_units=regexpi(headers,'QOI.\((\w*)\)','tokens'); %QOI._(\w*)
c_units=[c_units{:}]; c_units=[c_units{:}];
headers=regexprep(headers,'QOI(?<Channel>.)\((\w*)\)','QOI$<Channel>');
c_units_f=strcat(headers(~cellfun(@isempty,regexpi(headers,'QOI.')))',repmat({'_Units'},size(c_units,2),1));
P_field_c=[P_field_c;c_units_f];
P_data_c=[P_data_c;c_units'];

% Imports Numerical Data
data=textscan(fileID,D_FS,D_eRow(1)-D_sRow(1)+1,'Delimiter',D_del,'EmptyValue',NaN,'ReturnOnError',false);
data=data(:,1:end-1);
P_field_c=[P_field_c;headers'];
P_data_c=[P_data_c;data'];

% Close the text file.
fclose(fileID);

%% Sets Imported Data to a Structure
P_data=cell2struct(P_data_c,P_field_c,1);

end