%% Pressure Logging File Analysis
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
%% Script Information
% Written By: Alexander Herman
% U.S. Food and Drug Administration 
% Revised: 17-Aug-2021
%
% P_ANALYSIS is a script that import pressure logging files outputted from
% our pressure transducer setup. This Script imports a pressure transducer
% log file and calculates the average pressure after the index the script
% finds when the flow controller was turned on plus an offset. This is
% repeated for every log file in the same directory and a report can be
% generated.
%
% This script is designed to read pressure data from two differential
% pressure transducers of different sensitivities. It averages the
% pressures from both transducers and only selects the reading from the
% transducer that is the most sensitive where it does not clip. This code
% can be used for any pressure unit specified (Quantity of Interest [QOI]).
% This script can also be used with one transducer
%
% Requires: MATLAB R2006a (Tested with R2020b & R2014b) 
%
% NOTE: The functions used in this code are compatible with versions R2006a
% or before. However some input parameters and Name/Value pairs might not
% be compatible. Make sure function inputs used here and with supplied
% functions are compatible with the version of MATLAB being used to run
% this script.
%
% IMPORTANT: For the grouping of materials to happen properly, the
% nomenclature of the pressure files name must be the following format:
%
%       !Press#<material>#yyyy_mm_dd_HH-MM-SS
%
%   This format is based on the output of presslog.py and the script is
%   designed around it. 
%
%   !Press at the start of the file name identifies if this a pressure
%   logging file. Any files that does not have this tag and not have an
%   extention of TXT is not loaded for analysis.
%
%   <material> is the user entered material from the presslog.py and must
%   be sperated pound signs (#) at the start and end of the material. There
%   is a validation of the material in the file name and the material name
%   in the file. If there is a discrepancy, a warning is displayed.
%
%   After the material is a time stamp of when then the analysis started.
%   It must be in the format listed above as there is a validation of the
%   time stamp in the name and the time stamp in the file. If there
%   is a discrepancy, a warning is displayed.
%
% NOTE: Only one Flow Rate Can Summarized at a time. Code assumes all
% Pressure Logging files and cataloged under the same flow rate. This only
% affects the output of P_REPORT and the saved CSV.
%

%%  Inital Parameters
clear variables; close all; clc;

% Reporting Parameters
V_unit = 'SLPM'; % Units of the Vacuum Flow Rate (char format only)
V_q = 2.2; % Flow Rate of Pressure Files
fixture = '25mm Fixture'; % Fixture Used (char format only)
num_per = 5; % Percision of Numbers Outputed in the Report

% Offsets and Search Windows for Pressure Spike
f_offset = 150; % Front offset from Pressure Spike (Dwell, in # of Samples)
b_offset = 50; % Back Offset from End of Take (End Trim, in # of Samples)
sP_limit = 180; % Search Window (In Seconds) to Search for Pressure Spike

% Switches and Flags
p_bool = true; % Plot and Save Plot Pressure File Switch
std_name = true; % Use Standardized Names Switch
save_bool = true; % Save Reports Switch

% Transducer Parameters TD1 - Less Sensitive (or Only) Transducer, TD2 -
% More Sensitive Transducer 
% NOTE: If using only one transducer it must be
% assigned to TD1 and TD2_limit must be set to NaN. Both QOIs from both
% transducer are assumed to be the same unit
QOI_unit = 'mmH2O'; % Unit of Quantity of Intrest (char format only)
TD1 = 0; % Channel of Transducer 1 (0-3)
TD1_limit = 53.5; % Transducer 1 Limit (in Units of the QOI specified)
TD2 = 1; % Channel of Transducer 2 (0-3)
TD2_limit = NaN; % Transducer 2 Limit (in Units of the QOI specified)
t_d = 0.1; % Transducer Divergence Limit

%% Parameter Validation
if TD1==TD2
    error('P_analysis:E1','TD1 and TD2 cannot be the same channel')
elseif any([TD1,TD2]<0)&&any([TD1,TD2]<0)
    error('P_analysis:E2','TD1 and TD2 must between 0 and 3')
elseif ~all([TD1,TD2]==round([TD1,TD2]))
    error('P_analysis:E3','TD1 and TD2 must be intergers')
end

%% Gets List Pressure Logging Files
% Find Text files that have a "!Press" tag in the start of the file name
% Throws an errror if none are found
files = dir('!Press#*.txt');
if isempty(files)
    error('P_analysis:E4','No pressure files found, check current directory or added paths')
end
%% Initalizes Presure Report
% Initalizes Pressure Report as Cell Arrray
pt_headers = {'Date & Time',['Vacuum Flow Rate (',V_unit,')'],'Setup',...
    'Mask/Mask Materials',['ΔP (',QOI_unit,')'],'Transducer Channel',...
    ['Tranducer Range (',QOI_unit,')'],'Transducer Multiplier',...
    'Transducer Offset','Notes'};
p_report = cell(numel(files)+1,numel(pt_headers));
p_report(1,:)=pt_headers;

idx1 = 1;
for file = files'
    
    %% File Validation
    
    % Extract information about the log files via the name of the file,
    % considered to be not a valid file if the regex returns no match, if
    % one is found it displays a warning and moves to the next file
    fn_re = '#(?<Material>[^;]*)#(?<DateTime>\d+_\d+_\d+_\d+-\d+-\d+).txt$';
    fn_split=regexp({file.name},fn_re,'names');
    if cellfun('isempty',fn_split)
        warning('P_analysis:W1','%s is not a valid pressure file, please check the file',file.name)
        p_report=p_report(1:end-1,:); % Removes a row from the report cell array
        continue
    end
    fn_split = [fn_split{:}]; % Isolates the 1x1 structure from the cell
    
    % Import the specified pressure log file and generates Time Elasped
    Pdata = pDataImport(file.name);
    Pdata.tElasp_0 = Pdata.tElasp_s - Pdata.tElasp_s(1);
    
    % Validate Name and Loaded Data are the same
    dt_1 = datevec(Pdata.DateTime,'yyyy-mm-dd HH:MM:SS');
    dt_2 = datevec(fn_split.DateTime,'yyyy_mm_dd_HH-MM-SS');
    nameDT_check = all([all(dt_1==dt_2) strcmp(Pdata.Material,fn_split.Material)]);
    if ~nameDT_check
        warning('P_analysis:W2',['There is a discrepancy between the file name ',...
            'and the information in the following file:\n%s\nPlease check the file.'],file.name); 
    end
    
    % Feeds material name thru a standardizing name function and can
    % optionally use a lookup table to standardize the material name
    material = newMaterial(Pdata.Material,std_name);
    
    % Sets selected transducer channel to arrays to be processed and checks
    % units
    P_TD1 = Pdata.(['QOI',num2str(TD1)]);
    P_TD2 = Pdata.(['QOI',num2str(TD2)]);
    TD_u{1} = Pdata.(['QOI',num2str(TD1),'_Units']);
    if ~isnan(TD2_limit)
            TD_u{2} = Pdata.(['QOI',num2str(TD2),'_Units']);
    end
    unit_check = all(strcmp(QOI_unit,TD_u));
    if ~unit_check
        warning('P_analysis:W3',['There is a discrepancy between the units specified ',...
            'and the units in the following file:\n%s\nPlease check the file or change the units.'],file.name); 
    end
    
    %% Find Change in Pressure
    % If log file is shorter than fcp_limit (in Seconds) then find the
    % point where the pressure sharply changes (flow controller turned on)
    % within the whole sample else only look for sharp pressure change
    % within the first number of seconds specified by sP_limit. This
    % pressure change is found from the provided pSpike Function
    
    if isempty(find(Pdata.tElasp_0>sP_limit,1))
        pS_i=pSpike(P_TD1);
    else
        pS_i=pSpike(P_TD1(1:find(Pdata.tElasp_0>sP_limit,1)));
    end
    %% Calculate Average Pressures and Selects Proper Average for Report
    % Find the average pressure from the point where it finds when the
    % pressure controller is turned on plus an offset (f_offset) to the end
    % of the log file minus a second offset (b_offset)
    P_avg_T1 = mean(P_TD1(pS_i+f_offset:end-b_offset));
    P_avg_T2 = mean(P_TD2(pS_i+f_offset:end-b_offset));
    
    % If average pressure is not valid, then the offsets are reduced by
    % half until a valid average is found
    while isnan(P_avg_T1)
        f_offset = round(f_offset/2,0);
        b_offset = round(b_offset/2,0);
        P_avg_T1 = mean(P_TD1(pS_i+f_offset:end-b_offset));
        P_avg_T2 = mean(P_TD2(pS_i+f_offset:end-b_offset));
    end
    
    % Determines final pressure reading to use based off the limits of
    % transducer and transducer divergence, will default to TD1 if pressure
    % difference between TD1 & TD2 is greater than divergence specifed
    if P_avg_T1 <= TD2_limit && abs(P_avg_T1-P_avg_T2)<=t_d
        % Utilizes more sensitive transducer (TD2) for p_avg
        P_avg = P_avg_T2;
        note = '';
        P2_skip = false;
        TD = TD2;
        TD_lim = TD2_limit;
        TD_M = Pdata.(['QOI',num2str(TD2),'_Multi']);
        TD_OS = Pdata.(['QOI',num2str(TD2),'_Offset']);
    else
        % Utilizes less sensitive transducer (TD1) for p_avg
        P_avg = P_avg_T1;
        if P_avg > TD1_limit
            note = 'Reading was Clipped';
        else
            note = '';
        end
        P2_skip = true;
        TD = TD1;
        TD_lim = TD1_limit;
        TD_M = Pdata.(['QOI',num2str(TD1),'_Multi']);
        TD_OS = Pdata.(['QOI',num2str(TD1),'_Offset']);
    end
    
    %% Generate Selected Outputs and Add Average Pressure to Report
    
    % Adds result to the pressure report
    p_report(idx1+1,:) = {Pdata.DateTime,V_q,fixture,material,P_avg,TD,TD_lim,TD_M,TD_OS,note};
    
    if p_bool % Plot the pressure log file (If switch is enabled)
        
        % Formats ylabel for subscript
        if strcmp('mmH2O',QOI_unit)
            y_unit = 'mmH_2O';
        else
            y_unit = QOI_unit;
        end
        
        fig = figure(1); %#ok<UNRCH>
        if P2_skip % If P2 is clipped, it won't be plotted
            plot(Pdata.tElasp_0,P_TD1)
            ldg = {'P1',['P_{avg} = ',num2str(P_avg,3),' ',y_unit],...
                ['pSpike @ ',num2str(Pdata.tElasp_0(pS_i),'%.1f'),' s']};
        else
            plot(Pdata.tElasp_0,P_TD1,Pdata.tElasp_0,P_TD2)
            ldg = {'P1','P2',['P_{avg} = ',num2str(P_avg,3),' ',y_unit],...
                ['pSpike @ ',num2str(Pdata.tElasp_0(pS_i),'%.1f'),' s']};
        end
        
        title([Pdata.Material,' ',Pdata.DateTime])
        xlabel('Time (s)')
        ylabel(['\DeltaP (',y_unit,')'])
        hold on
        plot([Pdata.tElasp_0(pS_i),Pdata.tElasp_0(end)],repmat(P_avg,1,2),'k-')
        plot(repmat(Pdata.tElasp_0(pS_i),1,2)',repmat(get(gca,'ylim')',1,numel(Pdata.tElasp_0(pS_i))),'g--')
        legend(ldg,'Location','best')
        
        % Save a PNG and FIG of the Pressure Plots
        saveas(fig,[Pdata.Material,' ',strrep(Pdata.DateTime,':','-')],'fig')
        saveas(fig,[Pdata.Material,' ',strrep(Pdata.DateTime,':','-')],'png')
        close(fig)
    end
    idx1=idx1+1; % Iterates index of all files processed
end
idx1=idx1-1; % Returns idx to correct number of files processed

%% Generates Summary Reports and Selected Outputs
% Generates summary report, utilizes ACCUMARRAY for means, standard
% devations, and group counts. Additional summary methods can be added by
% adding another header in pst_headers and another call to ACCUMARRAY
[all_names,~,ic] = unique(p_report(2:end,strcmp('Mask/Mask Materials',p_report(1,:))));
pst_headers = {'Mask/Mask Materials','GroupCount',['Avg_P (',QOI_unit,')']',...
    ['Std_P (',QOI_unit,')'],'AvgP±StdP'};
pst_cell = cell(numel(all_names)+1,numel(pst_headers));
pst_cell(1,:)=pst_headers;
p_report_dp = p_report(2:end,strcmp(['ΔP (',QOI_unit,')'],p_report(1,:)));
p_report_dp = [p_report_dp{:}]';
pst_cell(2:end,1) = all_names;
pst_cell{2:end,2} = accumarray(ic, 1);
[pst_cell{2:end,3},Pavg_array] = deal(accumarray(ic, p_report_dp, [], @mean));
[pst_cell{2:end,4},Pstd_array] = deal(accumarray(ic, p_report_dp, [], @std));
pst_cell{2:end,5} = [num2str(Pavg_array,'%.2f'),repmat(' ± ',numel(all_names),1),num2str(Pstd_array,'%.2f')];

if save_bool
    % Outputs the cell arrays via FPRINTF 
    % All Pressure Data
%         TO1_cell = p_report'; %#ok<UNRCH>
%         TO1_num = cellfun(@isnumeric,TO1_cell);
%         TO1_cell(TO1_num) = cellstr(num2str([TO1_cell{TO1_num}]',num_per));
%         [TO1_r,TO1_c] = size(TO1_cell);
%         TO1_fs = repmat([repmat('%s,',1,TO1_r-1),'%s\n'],1,TO1_c);
%         TO1 = fopen('P_data.csv','w');
%         fprintf(TO1,TO1_fs,TO1_cell{:});
%         fclose(TO1);
    pCell2CSV(p_report,'P_data',num_per)
    
    % Summary Report
%         TO2_cell = pst_cell';
%         TO2_num = cellfun(@isnumeric,TO2_cell);
%         TO2_cell(TO2_num) = cellstr(num2str([TO2_cell{TO2_num}]',num_per));
%         [TO2_r,TO2_c] = size(TO2_cell);
%         TO2_fs = repmat([repmat('%s,',1,TO2_r-1),'%s\n'],1,TO2_c);
%         TO2 = fopen('P_summary.csv','w');
%         fprintf(TO2,TO2_fs,TO2_cell{:});
%         fclose(TO2);
    pCell2CSV(pst_cell,'P_summary',num_per)
end
