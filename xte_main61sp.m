%% Required Parameters
% Directory of the raw data
dirName = 'D:\temptemp\transfer_11957920_files_69f288a4\20260129_OK\20260129_OK\'; % An example

MID = 45;

%% Optional Parameters
% Needed when ramped sampling is used (i.e., when Grf != G)
Gdelays = [0 2 4]; % us

% Needed when compressed sensing is used (i.e., Acc > 1)
TV = 1e-2;
l1 = 1e-2;

% Maximum number of iterations during iterative reconstruction
ADMM_iter = 1000;

% BART Path in WSL 
BART_Path = '/mnt/c/Bart/bart-0.9.00';

% kernel width in oversampled grid samples during re-gridding operation
wg = 3;

% Enable Hamming filter
ifHamm = 1;

% Enable DICOM Output
ifDicom = 0;
ifNIfTI = 1;

%% Reconstruct
clear s
s = xte61sp(dirName,MID,'wg',wg,'ifHamm',ifHamm,'ifDicom',ifDicom,'ifNIfTI',ifNIfTI,'Gdelays',Gdelays,'TV',TV,'l1',l1,'ADMM_iter',ADMM_iter,'BART_Path',BART_Path);
DrawSingle(s.imFinal)