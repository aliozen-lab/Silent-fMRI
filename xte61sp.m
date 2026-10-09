classdef xte61sp < handle
   properties (Access = public)
      dirName
      fileno

      gammabar = 42577478.92;

      sequence
      acqBW

      ifSilent

      ifComplexOutput=0;

      ifMetal

      ifUTEmc
      ifLeaf
      leafTE
      Gleaf
      dataLeaf
      Nleaf
      TencLeaf
      GdelaysLeaf1
      GdelaysLeaf2
      GxLeaf1
      GyLeaf1
      GzLeaf1
      GxLeaf2
      GyLeaf2
      GzLeaf2
      krLeaf

      dr
      FOV
      BR
      BRleaf
      N
      Nspi = 1;
      N2
      TR
      TI
      FA
      taup
      
      flatTime
      flatTime2
      Tenc
      TE
      spiTE
      tGap
      tGapSpi

      spiOS
      td
      Nspokes

      slewRate
      Grf
      G

      Gdelays
      Gdelays2
      Gwave
      Gx
      Gy
      Gz

      rampTime
      rampTimeAll
      tt

      ifSPI = 1;
      kgapN

      Acc = 1;
      aAcc = 1; %artificial Acceleration
      num = 1; %just for loops
      Ncalib

      ifWE = 0;
      ifFS = 0;
      ifIR = 0;
      ifMagPrep = 0;
      fsPeriod = 10;

      ifDE = 0;

      ifSpoil = 1;

      rawdata
      dataR
      dataGRE
      dataC

      numPartsSpokes
      numChannels
      numMeas

      kxR
      kyR
      kzR

      kxC
      kyC
      kzC

      kxR2
      kyR2
      kzR2

      kxLeaf1
      kxLeaf2

      kyLeaf1
      kyLeaf2

      kzLeaf1
      kzLeaf2

      drLeaf
      kmaxLeaf

      dk
      kmax

      kr

      offcenter
      XShift
      YShift
      ZShift

      ifHamm = 1;
      hamm
      hammLeaf
      
      gridOS = 2;
      wg = 3;
      OS = 2;
      DCF
      DCF_SPI
      DCF2
      DCFleaf1
      DCFleaf2

      dirX
      dirY
      dirZ

      spiData

      BART_Path

      lambdaTV;
      lambdal1;
      ADMM_iter;

      ims
      ims2

      imFinal
      imFinal2
      imFinalZeroFill

      imsLeaf1
      imsLeaf2
      imFinalLeaf1
      imFinalLeaf2
   end

   methods
      function obj = xte61sp(dirName,fileno,varargin)
         p = inputParser;
         addParameter(p, 'gridOS', 2, @isnumeric);
         addParameter(p, 'wg',         3,  @isnumeric);
         addParameter(p, 'ifSave',     0,  @isnumeric);
         addParameter(p, 'ifHamm',     1,  @isnumeric);
         addParameter(p, 'ifRecon',    1,  @isnumeric);
         % addParameter(p, 'ifDicom',    1,  @isnumeric);
         addParameter(p, 'ifDicom',    1,  @isnumeric);
         addParameter(p, 'ifNifti',    1,  @isnumeric);
         addParameter(p, 'ifComplexOutput',  0, @isnumeric);

         addParameter(p, 'BART_Path', '/mnt/c/Bart/bart-0.9.00',  @ischar);
         addParameter(p, 'Number',  1, @isnumeric);
         addParameter(p, 'TV',           0.01, @isnumeric);
         addParameter(p, 'l1',           0.01, @isnumeric);
         addParameter(p, 'ADMM_iter',    100, @isnumeric);
       
         addParameter(p, 'Gdelays',  [0 2 4], @isnumeric);
         addParameter(p, 'Gdelays2', [0 0 0], @isnumeric);

         parse(p,varargin{:});

         obj.dirName = dirName;
         obj.gridOS = p.Results.gridOS;
         obj.fileno = num2str(fileno);
         obj.wg = p.Results.wg;
         obj.ifHamm = p.Results.ifHamm;

         ifSave = p.Results.ifSave;
         ifRecon = p.Results.ifRecon;
         ifDicom = p.Results.ifDicom;
         ifNifti = p.Results.ifNifti;
         obj.ifComplexOutput = p.Results.ifComplexOutput;

         obj.Gdelays  = p.Results.Gdelays*1e-6;
         obj.Gdelays2 = p.Results.Gdelays2*1e-6;

         obj.BART_Path = p.Results.BART_Path;
         
         obj.num = p.Results.Number;%this is just for loops to write in dicom name
         obj.lambdaTV  = p.Results.TV;
         obj.lambdal1  = p.Results.l1;
         obj.ADMM_iter = p.Results.ADMM_iter;

         if numel(obj.fileno) < 5
            switch numel(obj.fileno)
               case 0
                  obj.fileno = '00000';
               case 1
                  obj.fileno = ['0000' obj.fileno];
               case 2
                  obj.fileno = ['000' obj.fileno];
               case 3
                  obj.fileno = ['00' obj.fileno];
               case 4
                  obj.fileno = ['0' obj.fileno];
            end
         elseif numel(obj.fileno) > 5
            fprintf('Use 5-decimal format\n')
            return
         end

         obj.readData;

         if ifRecon
            obj.calcDirectionVector;
            obj.calcTrajs;

            if obj.ifHamm
               obj.calcHamming;
               obj.calcHammingLeaf;
            end

            obj.calcFOV_Shifter;
            obj.reconAll;

            obj.textParams;
            %obj.correctOrientations;

            if ifDicom
               fprintf('Writing DICOMs...\n')
               for ii = 1:obj.numMeas
                  % obj.dicomWrite('ZTE',ii,obj.num);%achtung hier num entfernen
                  obj.dicomWrite('ZTE',ii);
                  if or(obj.Acc > 1, obj.aAcc > 1)
                     obj.dicomWrite('ZeroFill',ii,obj.num);
                  end
                  if obj.ifDE
                     obj.dicomWrite('GRE',ii);
                     obj.dicomWrite('SUBS',ii);
                  end
                  if obj.ifWE && obj.Gleaf > 0
                     obj.dicomWrite('Leaf1',ii);
                     obj.dicomWrite('Leaf2',ii);
                  end
               end
               fprintf('DICOMs are ready.\n')
            end

            if ifNifti
               fprintf('Writing NIfTIs...\n')

               obj.niftiWrite('ZTE');
               if obj.ifDE
                  obj.niftiWrite('GRE');
                  obj.niftiWrite('SUBS');
               end
               if obj.ifWE && obj.Gleaf > 0
                  obj.niftiWrite('Leaf1');
                  obj.niftiWrite('Leaf2');
               end

               fprintf('NIfTIs are ready.\n')
            end

            if ifSave
               obj.saveObj;
            end
         end
      end

      function readData(obj)
         listing = dir(obj.dirName);
         for ii = 3:length(listing)
            name = listing(ii).name;
            if contains(name,obj.fileno) && contains(name,'.dat') && ~contains(name,'.txt')
               filename = listing(ii).name;
               break;
            end
         end

         try
            temp = strcat(obj.dirName,filename);
            obj.rawdata = mapVBVD(temp);
         catch
            fprintf('File cannot be read:\n%10s %s\n%10s %s\n\n', 'Directory:', obj.dirName, 'MID:', obj.fileno);
            return
         end
         if numel(obj.rawdata) > 1
            obj.rawdata = obj.rawdata{end};
         end

         fprintf('Rawdata is read.\n');

         obj.getParams;

         obj.getZTEData;
         obj.getSPIData;
         obj.getLeafData;
         obj.getGREData;
      end

      function calcTrajs(obj)
         if obj.sequence == 2 % UTE
            obj.calcUTETraj;
         else
            obj.calcZTETraj;
         end
         obj.calcSPITraj;
         obj.calcLeafTraj1;
         obj.calcLeafTraj2;
         obj.calcGRETraj;
      end

      function reconAll(obj)
         obj.recon;
         obj.reconLeaf1;
         obj.reconLeaf2;
         obj.reconGRE;
      end

      function getParams(obj)
         numDoubles = numel(obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree);
         numLongs = numel(obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree);

         for ii = 1:numLongs
            if isempty(obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{ii})
               obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{ii} = 0;
            end
         end

         for ii = 1:numDoubles
            if isempty(obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{ii})
               obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{ii} = 0;
            end
         end

         obj.FOV = obj.rawdata.hdr.Config.ReadFoV*1e-3; % [m]
         obj.BR = obj.rawdata.hdr.Config.BaseResolution;
         obj.dr = obj.FOV/obj.BR; % [m]

         if ~strcmp(obj.rawdata.hdr.Phoenix.tSequenceFileName, "%CustomerSeq%\xte") &&...
               ~strcmp(obj.rawdata.hdr.Phoenix.tSequenceFileName, "%CustomerSeq%\si_petra")
            fprintf('\n\nERROR: Selected raw-data was not acquired with XTE:\nDirectory: %s\n      MID: %s\n\n', obj.dirName, obj.fileno);
            return
         end

         obj.TR = obj.rawdata.hdr.Config.TR*1e-6; % [s]
         obj.TI = obj.rawdata.hdr.Config.TI*1e-6; % [s]
         obj.FA = obj.rawdata.hdr.MeasYaps.adFlipAngleDegree{1}; % [°]
         obj.TE = obj.rawdata.hdr.MeasYaps.alTE{1}*1e-6; % [s]

         obj.sequence = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{1};
         %obj.acqBW    = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{2};
         obj.ifSilent = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{2};%3
         obj.slewRate = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{3};%if slew rate cant be modified 190; % [T/m/s]
         obj.td  = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{4}*1e-9; %[s]
         obj.Nspokes  = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{5};
         obj.ifMetal  = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{6};
         obj.spiTE    = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{7}*1e-6; % [s]
         obj.spiOS    = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{8};
         obj.ifWE     = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{9};
         obj.ifUTEmc  = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{10};
         obj.ifLeaf   = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{11};
         obj.leafTE   = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{12};
         obj.ifDE     = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{13};
         obj.fsPeriod = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{14};
         % obj.tt       = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{14}*1e-6; % [s]
        

         obj.Acc      = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{2};%1
         obj.Ncalib   = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{3};
         obj.Grf      = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{4}*1e-3;   % [T/m]
         obj.G        = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{5}*1e-3;   % [T/m] adfree1
         obj.taup     = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{6}*1e-6;   % [s]
         obj.rampTime = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{7}*1e-6;   % [s]
         obj.flatTime = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{8}*1e-6;   % [s]
         obj.dk       = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{9};        % [1/m]
         obj.kmax     = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{10};       % [1/m]
         % obj.td       = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{11}*1e-9;  % [s]
         obj.kgapN    = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{12};
         obj.gammabar = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{13}*1e6;   % [Hz/T]
         obj.Tenc     = obj.rawdata.hdr.Phoenix.sWipMemBlock.adFree{14}*1e-6;  % [s]
         if obj.flatTime <=0
             obj.Tenc = obj.Tenc + abs(obj.flatTime);
             obj.flatTime = 0;             
         end
         obj.Ncalib = round(obj.Ncalib);

         obj.Gleaf = 0e-3; % [T/m]

         % obj.slewRate = obj.rawdata.hdr.Phoenix.sWipMemBlock.alFree{3};%if slew rate cant be modified 190; % [T/m/s]
         % if obj.slewRate == 0
         %     obj.slewRate = 190;
         % end
         obj.tGap = obj.TE-obj.taup/2;
         obj.tGapSpi = obj.spiTE - obj.taup/2; % [s]

         obj.ifFS = 0;
         obj.ifIR = 0;

         obj.tt  =      (round(obj.taup*1e6,-1)-obj.taup*1e6 + 20)*1e-6;
         % if obj.rawdata.hdr.MeasYaps.sPrepPulses.ucFatSat == 1
         %   obj.ifFS = 1;
         % end

         if obj.rawdata.hdr.MeasYaps.sPrepPulses.ucInversion == 2
            obj.ifIR = 1;
         end

         % obj.Acc = 1;
         obj.ifMagPrep = obj.ifFS + obj.ifIR;
      end

      function getZTEData(obj)
         if ~obj.Nspokes
            return
         end

         fprintf('Extracting spokes...\n');

         obj.dataR = obj.rawdata.image();
         obj.numPartsSpokes = 1;
         obj.numMeas = 1;
         obj.numChannels = size(obj.dataR,2);

         if ndims(obj.dataR) > 8
            obj.numMeas = size(obj.dataR,9);
         end
         if ndims(obj.dataR) > 3
            obj.numPartsSpokes = size(obj.dataR,4);
         end

         obj.N = size(obj.dataR,1);

         if obj.numPartsSpokes > 1
            fprintf('Reordering spokes...\n');

            temp = complex(zeros(obj.N,obj.numChannels,obj.Nspokes,obj.numMeas,'single'));
            extra = obj.Nspokes - (obj.numPartsSpokes-1)*65536;
            for ii = 1:obj.numPartsSpokes-1
               fprintf('%d/%d\n', ii, obj.numPartsSpokes-1);

               temp(:,:,(1:65536) + (ii-1)*65536,:,:) = obj.dataR(:,:,:,ii,:,:);
            end
            temp(:,:,end-extra+1:end,:,:) = obj.dataR(:,:,1:extra,obj.numPartsSpokes,:,:);
            obj.dataR = temp;
         end

         obj.dataR = reshape(obj.dataR,obj.N,obj.numChannels,obj.Nspokes,obj.numMeas);

         fprintf('Spokes are reordered.\n');
      end

      function getGREData(obj)
         if ~obj.ifDE || ~obj.Nspokes
            return
         end
         fprintf('Extracting radials...\n');

         obj.dataGRE = obj.rawdata.RTfeedback();

         obj.N2 = size(obj.dataGRE,1);

         if obj.numPartsSpokes > 1
            fprintf('Reordering radials...\n');

            temp = complex(zeros(obj.N2,obj.numChannels,obj.Nspokes,obj.numMeas,'single'));
            extra = obj.Nspokes - (obj.numPartsSpokes-1)*65536;
            for ii = 1:obj.numPartsSpokes-1
               fprintf('%d/%d\n', ii, obj.numPartsSpokes-1);

               temp(:,:,(1:65536) + (ii-1)*65536,:,:) = obj.dataGRE(:,:,:,ii,:,:);
            end
            temp(:,:,end-extra+1:end,:,:) = obj.dataGRE(:,:,1:extra,obj.numPartsSpokes,:,:);
            obj.dataGRE = temp;
         end

         fprintf('Radials are reordered.\n');
      end

      function getSPIData(obj)
         if isfield(obj.rawdata,'noise')
            obj.ifSPI = 1;

            fprintf('Re-ordering SPI data...\n')
            obj.dataC = obj.rawdata.noise();
            obj.dataC = obj.dataC(6:5+obj.Nspi,:,:,:,:,:,:,:,:,:,:,:,:,:);
            obj.dataC = permute(obj.dataC,[1 12 13 14 2 9 3 4 5 6 7 8 10 11]);
            fprintf('SPI data re-ordered.\n')

            obj.numChannels = size(obj.dataC,5);
            obj.numMeas = size(obj.dataC,6);

            if obj.spiTE <= obj.TE + 5*obj.td
               fprintf('Vectorizing SPI data...\n')
               obj.spiData = zeros(obj.Nspi,(2*obj.kgapN+1)^3,obj.numChannels,obj.numMeas,'single');

               count = 1;
               for x = -obj.kgapN:obj.kgapN
                  for y = -obj.kgapN:obj.kgapN
                     for z = -obj.kgapN:obj.kgapN
                        obj.spiData(:,count,:,:) = obj.dataC(:,x+obj.kgapN+1,y+obj.kgapN+1,z+obj.kgapN+1,:,:);
                        count = count+1;
                     end
                  end
               end
               fprintf('SPI data vectorized.\n')
            end
         else
            obj.ifSPI = 0;
         end
      end

      function getLeafData(obj)
         if ~obj.ifWE || obj.Gleaf <= 0
            return
         end
         fprintf('Reading leaves...\n');

         obj.dataLeaf = obj.rawdata.phasecor();

         obj.Nleaf = size(obj.dataLeaf,1);

         if obj.numPartsSpokes > 1
            fprintf('Reordering leaves...\n');

            temp = complex(zeros(obj.Nleaf,obj.numChannels,obj.Nspokes,obj.numMeas,'single'));
            extra = obj.Nspokes - (obj.numPartsSpokes-1)*65536;
            for ii = 1:obj.numPartsSpokes-1
               temp(:,:,(1:65536) + (ii-1)*65536,:,:) = obj.dataLeaf(:,:,:,ii,:,:);
            end
            temp(:,:,end-extra+1:end,:,:) = obj.dataLeaf(:,:,1:extra,obj.numPartsSpokes,:,:);
            obj.dataLeaf = temp;
         end

         fprintf('Leaves are reordered.\n');
      end

      function calcDirectionVector(obj)
         spoke = single(1:obj.Nspokes);
         obj.dirZ = (2*spoke-obj.Nspokes-1)/obj.Nspokes;
         obj.dirY = sin(sqrt(obj.Nspokes*pi)*asin(obj.dirZ)).*sqrt(1-obj.dirZ.^2);
         obj.dirX = cos(sqrt(obj.Nspokes*pi)*asin(obj.dirZ)).*sqrt(1-obj.dirZ.^2);
      end

      function calcUTETraj(obj)
         if ~obj.Nspokes
            return
         end

         NGrf  = round(obj.TE/obj.td);
         NRamp = round(obj.rampTime/obj.td);
         NFlat = round(obj.flatTime/obj.td);

         waveGrf  = zeros(1,NGrf);
         waveFlat = obj.G*ones(1,NFlat);

         waveRamp = zeros(1,NRamp);
         if NRamp
            dG = obj.G/NRamp;
            waveRamp = dG*(1:NRamp);
         end

         obj.Gwave = [waveGrf waveRamp waveFlat obj.G obj.G obj.G obj.G];

         t       = (0:obj.td:(numel(obj.Gwave)-1)*obj.td);
         tFine   = (0:0.1e-6:(numel(obj.Gwave)-1)*obj.td);

         Gsmooth = interp1(t, obj.Gwave, tFine, 'linear', 'extrap');

         Nx = 0;
         Ny = 0;
         Nz = 0;
         if sum(abs(obj.Gdelays)) > 0
            Nx = find(tFine-obj.Gdelays(1)<1e-12,1,'last');
            Ny = find(tFine-obj.Gdelays(2)<1e-12,1,'last');
            Nz = find(tFine-obj.Gdelays(3)<1e-12,1,'last');
         end

         obj.Gx = [zeros(1,Nx) Gsmooth(1:end-Nx)];
         obj.Gy = [zeros(1,Ny) Gsmooth(1:end-Ny)];
         obj.Gz = [zeros(1,Nz) Gsmooth(1:end-Nz)];

         obj.Gx = interp1(tFine, obj.Gx, t, 'spline', 0);
         obj.Gy = interp1(tFine, obj.Gy, t, 'spline', 0);
         obj.Gz = interp1(tFine, obj.Gz, t, 'spline', 0);

         % figure, plot(obj.Gwave), hold on, plot(obj.Gx), plot(obj.Gy), plot(obj.Gz), hold off

         obj.kxR = zeros(obj.N,obj.Nspokes,'single');
         obj.kyR = zeros(obj.N,obj.Nspokes,'single');
         obj.kzR = zeros(obj.N,obj.Nspokes,'single');

         thisGx = obj.Gx(NGrf+1:NGrf+obj.N)'*obj.dirX;
         thisGy = obj.Gy(NGrf+1:NGrf+obj.N)'*obj.dirY;
         thisGz = obj.Gz(NGrf+1:NGrf+obj.N)'*obj.dirZ;

         obj.kxR = cumsum(obj.gammabar*obj.td.*thisGx,1);
         obj.kyR = cumsum(obj.gammabar*obj.td.*thisGy,1);
         obj.kzR = cumsum(obj.gammabar*obj.td.*thisGz,1);

         % kR = sqrt(obj.kxR.^2+obj.kyR.^2+obj.kzR.^2);
         % figure, plot(kR(:,1000)), axis tight
         % figure, plot(obj.kxR(end,:)), hold on, plot(obj.kyR(end,:)), plot(obj.kzR(end,:)), axis tight

         % Normalize k-space
         obj.kxR = obj.kxR/obj.kmax*0.5;
         obj.kyR = obj.kyR/obj.kmax*0.5;
         obj.kzR = obj.kzR/obj.kmax*0.5;

         temp = ones(obj.N,obj.Nspokes);
         obj.DCF = gridkb3D(temp(:), obj.kxR(:), obj.kyR(:), obj.kzR(:), obj.BR, obj.OS, obj.wg);%OS=2
         obj.DCF(obj.DCF < .01) = 1;

         fprintf('3D trajectory and DCF for spokes is calculated.\n');
      end

      function calcZTETraj(obj)
         if ~obj.Nspokes
            return
         end

         NGrf  = round((obj.taup/2+obj.tt)/obj.td);
         NRamp = round(obj.rampTime/obj.td);
         NFlat = round(obj.flatTime/obj.td);

         waveGrf = obj.Grf*ones(1,NGrf);
         waveFlat = obj.G*ones(1,NFlat);

         waveRamp = zeros(1,NRamp);
         if NRamp
            dG = (obj.G-obj.Grf)/NRamp;
            waveRamp = obj.Grf + dG*(1:NRamp);
         end

         obj.Gwave = [waveGrf waveRamp waveFlat obj.G obj.G obj.G obj.G]; % 3 G eklendi

         if obj.G == obj.Grf
            obj.Gx = obj.Gwave;
            obj.Gy = obj.Gwave;
            obj.Gz = obj.Gwave;
         else
            t       = (0:obj.td:obj.Tenc+3*obj.td);
            tFine   = (0:0.1e-6:obj.Tenc+3*obj.td);

            Gsmooth = interp1(t, obj.Gwave, tFine, 'linear', 'extrap');

            Nx = 0;
            Ny = 0;
            Nz = 0;
            if sum(abs(obj.Gdelays)) > 0
               Nx = find(tFine-obj.Gdelays(1)<1e-12,1,'last');
               Ny = find(tFine-obj.Gdelays(2)<1e-12,1,'last');
               Nz = find(tFine-obj.Gdelays(3)<1e-12,1,'last');
            end

            obj.Gx = [ones(1,Nx)*obj.Grf Gsmooth(1:end-Nx)];
            obj.Gy = [ones(1,Ny)*obj.Grf Gsmooth(1:end-Ny)];
            obj.Gz = [ones(1,Nz)*obj.Grf Gsmooth(1:end-Nz)];

            obj.Gx = interp1(tFine, obj.Gx, t, 'spline', 0);
            obj.Gy = interp1(tFine, obj.Gy, t, 'spline', 0);
            obj.Gz = interp1(tFine, obj.Gz, t, 'spline', 0);

            % figure, plot(obj.Gwave), hold on, plot(obj.Gx), plot(obj.Gy), plot(obj.Gz), hold off
         end

         obj.kxR = zeros(obj.N,obj.Nspokes,'single');
         obj.kyR = zeros(obj.N,obj.Nspokes,'single');
         obj.kzR = zeros(obj.N,obj.Nspokes,'single');

         t0 = obj.taup/2+obj.tGap+obj.td/2;
         if obj.Grf == obj.G
            t = t0:obj.td:t0+obj.td*(obj.N-1);
            t = repmat(t',1,obj.Nspokes);

            thisGx = obj.Gx(end-obj.N+1:end)'*obj.dirX;
            thisGy = obj.Gy(end-obj.N+1:end)'*obj.dirY;
            thisGz = obj.Gz(end-obj.N+1:end)'*obj.dirZ;

            obj.kxR = obj.gammabar*t.*thisGx;
            obj.kyR = obj.gammabar*t.*thisGy;
            obj.kzR = obj.gammabar*t.*thisGz;
         else
            Ngap = round(t0/obj.td);

            gapGx = obj.Gx(1:Ngap)'*obj.dirX;
            gapGy = obj.Gy(1:Ngap)'*obj.dirY;
            gapGz = obj.Gz(1:Ngap)'*obj.dirZ;

            thisGx = obj.Gx(Ngap+1:Ngap+obj.N)'*obj.dirX;
            thisGy = obj.Gy(Ngap+1:Ngap+obj.N)'*obj.dirY;
            thisGz = obj.Gz(Ngap+1:Ngap+obj.N)'*obj.dirZ;

            gapKx = cumsum(obj.gammabar*obj.td.*gapGx,1);
            gapKy = cumsum(obj.gammabar*obj.td.*gapGy,1);
            gapKz = cumsum(obj.gammabar*obj.td.*gapGz,1);

            obj.kxR = gapKx(end,:) + cumsum(obj.gammabar*obj.td.*thisGx,1);
            obj.kyR = gapKy(end,:) + cumsum(obj.gammabar*obj.td.*thisGy,1);
            obj.kzR = gapKz(end,:) + cumsum(obj.gammabar*obj.td.*thisGz,1);
         end

         % kR = sqrt(obj.kxR.^2+obj.kyR.^2+obj.kzR.^2);
         % figure, plot(kR(:,10000)), axis tight
         % figure, plot(obj.kxR(end,:)), hold on, plot(obj.kyR(end,:)), plot(obj.kzR(end,:)), axis tight

         % Normalize k-space
         obj.kxR = obj.kxR/obj.kmax*0.5;
         obj.kyR = obj.kyR/obj.kmax*0.5;
         obj.kzR = obj.kzR/obj.kmax*0.5;

         temp = ones(obj.N,obj.Nspokes);
         obj.DCF = gridkb3D(temp(:), obj.kxR(:), obj.kyR(:), obj.kzR(:), obj.BR, obj.OS, obj.wg);%OS=2
         obj.DCF(obj.DCF < .01) = 1;

         fprintf('3D trajectory and DCF for spokes is calculated.\n');
      end

      function calcSPITraj(obj)
         if obj.spiTE > obj.TE + 5*obj.td
            return
         end

         obj.kxC = zeros(obj.Nspi,(2*obj.kgapN+1)^3,'single');
         obj.kyC = zeros(obj.Nspi,(2*obj.kgapN+1)^3,'single');
         obj.kzC = zeros(obj.Nspi,(2*obj.kgapN+1)^3,'single');

         t0 = (obj.spiTE+1e-6/2);
         t = t0:1e-6:t0+(obj.Nspi-1)*1e-6;

         count = 1;
         for x = -obj.kgapN:obj.kgapN
            for y = -obj.kgapN:obj.kgapN
               for z = -obj.kgapN:obj.kgapN
                  r = sqrt(x*x+y*y+z*z);

                  k = 1.0*obj.dk*r;

                  thisGrf = k/t0/obj.gammabar;
                  thisGx = 0;
                  thisGy = 0;
                  thisGz = 0;

                  if r > 0
                      thisGx = thisGrf*x/r;
                      thisGy = thisGrf*y/r;
                      thisGz = thisGrf*z/r;
                  end

                  obj.kxC(:,count) = obj.gammabar*t*thisGx;
                  obj.kyC(:,count) = obj.gammabar*t*thisGy;
                  obj.kzC(:,count) = obj.gammabar*t*thisGz;

                  count = count + 1;
               end
            end
         end

         % Normalize k-space
         obj.kxC = obj.kxC/obj.kmax*0.5;
         obj.kyC = obj.kyC/obj.kmax*0.5;
         obj.kzC = obj.kzC/obj.kmax*0.5;

         temp = ones(obj.Nspi,(2*obj.kgapN+1)^3);%2*obj.kgapN
         obj.DCF_SPI = gridkb3D(temp(:), obj.kxC(:), obj.kyC(:), obj.kzC(:), obj.BR, obj.OS, obj.wg);%OS=2
         obj.DCF_SPI(obj.DCF_SPI < .01) = 1;

         fprintf('3D trajectory for spokes is calculated.\n');
      end

      function calcGRETraj(obj)
         if ~obj.ifDE || ~obj.Nspokes
            return
         end

         obj.kxR2 = zeros(obj.N2,obj.Nspokes,'single');
         obj.kyR2 = zeros(obj.N2,obj.Nspokes,'single');
         obj.kzR2 = zeros(obj.N2,obj.Nspokes,'single');

         thisG = -obj.G*ones(obj.N2,1);

         thisGx = thisG*obj.dirX;
         thisGy = thisG*obj.dirY;
         thisGz = thisG*obj.dirZ;

         obj.kxR2 = obj.gammabar*thisGx.*obj.td;
         obj.kyR2 = obj.gammabar*thisGy.*obj.td;
         obj.kzR2 = obj.gammabar*thisGz.*obj.td;

         % kR2 = sqrt(obj.kxR2.^2+obj.kyR2.^2+obj.kzR2.^2);
         % figure, plot(obj.kxR2(end,:)), hold on, plot(obj.kyR2(end,:)), plot(obj.kzR2(end,:)), axis tight
         % figure, plot(obj.kxR2(1,:)), hold on, plot(obj.kyR2(1,:)), plot(obj.kzR2(1,:)), axis tight

         obj.kxR2(1,:) = obj.kmax*obj.dirX - obj.gammabar*thisGx(1,:)*(10e-6-obj.Gdelays2(1));
         obj.kyR2(1,:) = obj.kmax*obj.dirY - obj.gammabar*thisGy(1,:)*(10e-6-obj.Gdelays2(2));
         obj.kzR2(1,:) = obj.kmax*obj.dirZ - obj.gammabar*thisGz(1,:)*(10e-6-obj.Gdelays2(3));

         obj.kxR2 = cumsum(obj.kxR2,1);
         obj.kyR2 = cumsum(obj.kyR2,1);
         obj.kzR2 = cumsum(obj.kzR2,1);

         % Normalize k-space
         obj.kxR2 = obj.kxR2/obj.kmax*0.5;
         obj.kyR2 = obj.kyR2/obj.kmax*0.5;
         obj.kzR2 = obj.kzR2/obj.kmax*0.5;

         temp = ones(obj.N2,obj.Nspokes);
         obj.DCF2 = gridkb3D(temp(:), obj.kxR2(:), obj.kyR2(:), obj.kzR2(:), obj.BR, 2, obj.wg);
         obj.DCF2(obj.DCF2 < .01) = 1;

         fprintf('3D trajectory and DCF for GRE radials is calculated.\n');
      end

      function calcLeafTraj1(obj)
         if ~obj.ifWE || obj.Gleaf <= 0
            return
         end

         if obj.ifLeaf
            obj.kSpaceLeaf1();
         else
            obj.kSpaceDipolar1();
         end

         kMax = max([obj.kxLeaf1 obj.kyLeaf1 obj.kzLeaf1],[],'all');
         obj.drLeaf = 1/kMax/2;
         obj.kmaxLeaf = kMax;

         % Normalize k-space
         obj.kxLeaf1 = obj.kxLeaf1/obj.kmaxLeaf*0.5;
         obj.kyLeaf1 = obj.kyLeaf1/obj.kmaxLeaf*0.5;
         obj.kzLeaf1 = obj.kzLeaf1/obj.kmaxLeaf*0.5;

         obj.BRleaf = round(obj.FOV/obj.drLeaf);
         if mod(obj.BRleaf,2)
            obj.BRleaf = obj.BRleaf + 1;
         end

         temp = ones(size(obj.kxLeaf1));
         obj.DCFleaf1 = gridkb3D(temp(:), obj.kxLeaf1(:), obj.kyLeaf1(:), obj.kzLeaf1(:), obj.BRleaf, 2, obj.wg);
         obj.DCFleaf1(obj.DCFleaf1 < .01) = 1;

         fprintf('3D trajectory and DCF for leaf-1 is calculated.\n');
      end

      function calcLeafTraj2(obj)
         if ~obj.ifWE || obj.Gleaf <= 0
            return
         end

         if obj.ifLeaf
            obj.kSpaceLeaf2();
         else
            obj.kSpaceDipolar2();
         end

         obj.kxLeaf2 = obj.kxLeaf2/obj.kmaxLeaf*0.5;
         obj.kyLeaf2 = obj.kyLeaf2/obj.kmaxLeaf*0.5;
         obj.kzLeaf2 = obj.kzLeaf2/obj.kmaxLeaf*0.5;

         temp = ones(size(obj.kxLeaf2));
         obj.DCFleaf2 = gridkb3D(temp(:), obj.kxLeaf2(:), obj.kyLeaf2(:), obj.kzLeaf2(:), obj.BRleaf, 2, obj.wg);
         obj.DCFleaf2(obj.DCFleaf2 < .01) = 1;

         fprintf('3D trajectory and DCF for leaf-2 is calculated.\n');
      end

      function kSpaceLeaf1(obj)
         Ng = obj.TencLeaf*1e6/10+1;

         step = 2*pi/(Ng-1);
         theta = (0:step:2*pi)';

         G1 = sin(theta);
         G2 = sin(2*theta)/2;
         G2(floor(Ng/2)+1:end) = -G2(floor(Ng/2)+1:end);

         G1 = repelem(G1,round(10e-6/obj.td));
         G2 = repelem(G2,round(10e-6/obj.td));

         thisGx = obj.Gleaf*(G1*obj.dirX+G2*obj.dirY);
         thisGy = obj.Gleaf*(G1*obj.dirY+G2*obj.dirZ);
         thisGz = obj.Gleaf*(G1*obj.dirZ+G2*obj.dirX);

         kx = cumsum(obj.gammabar*thisGx.*obj.td,1);
         ky = cumsum(obj.gammabar*thisGy.*obj.td,1);
         kz = cumsum(obj.gammabar*thisGz.*obj.td,1);

         ind1 = 4;
         ind2 = round(obj.TencLeaf/2/obj.td)+3;
         obj.kxLeaf1 = kx(ind1:ind2,:);
         obj.kyLeaf1 = ky(ind1:ind2,:);
         obj.kzLeaf1 = kz(ind1:ind2,:);
      end

      function kSpaceLeaf2(obj)
         Ng = obj.TencLeaf*1e6/10+1;

         step = 2*pi/(Ng-1);
         theta = (0:step:2*pi)';

         G1 = sin(theta);
         G2 = sin(2*theta)/2;
         G2(floor(Ng/2)+1:end) = -G2(floor(Ng/2)+1:end);

         G1 = repelem(G1,round(10e-6/obj.td));
         G2 = repelem(G2,round(10e-6/obj.td));

         thisGx = obj.Gleaf*(G1*obj.dirX+G2*obj.dirY);
         thisGy = obj.Gleaf*(G1*obj.dirY+G2*obj.dirZ);
         thisGz = obj.Gleaf*(G1*obj.dirZ+G2*obj.dirX);

         kx = cumsum(obj.gammabar*thisGx.*obj.td,1);
         ky = cumsum(obj.gammabar*thisGy.*obj.td,1);
         kz = cumsum(obj.gammabar*thisGz.*obj.td,1);

         ind  = round(obj.TencLeaf/2/obj.td)+4;
         ind2 = ind+round(obj.TencLeaf/2/obj.td);

         obj.kxLeaf2 = kx(ind:ind2,:);
         obj.kyLeaf2 = ky(ind:ind2,:);
         obj.kzLeaf2 = kz(ind:ind2,:);
      end

      function kSpaceDipolar1(obj)
         leafRampTime = roundUpTenMicroSec(obj.Gleaf/obj.slewRate);
         leafFlatTime = obj.TencLeaf/2-2*leafRampTime;

         NRamp = round(leafRampTime/obj.td);
         NFlat = round(leafFlatTime/obj.td);

         dG = obj.Gleaf/NRamp;
         waveRamp = dG*(1:NRamp);

         waveFlat = obj.Gleaf*ones(1,NFlat);

         GwaveLeaf = [0 0 0 waveRamp waveFlat fliplr(waveRamp) 0 0 0];

         leafN = size(obj.dataLeaf,1)/2;

         if numel(GwaveLeaf) < leafN
            GwaveLeaf = [GwaveLeaf zeros(1,leafN-numel(GwaveLeaf))];
         elseif numel(GwaveLeaf) > leafN
            GwaveLeaf = GwaveLeaf(1:leafN);
         end

         t     = 0:obj.td:leafN*obj.td-obj.td;
         tFine = 0:0.1e-6:leafN*obj.td-obj.td;

         Gsmooth = interp1(t, GwaveLeaf, tFine, 'linear', 'extrap');

         Nx = 0;
         Ny = 0;
         Nz = 0;
         if sum(abs(obj.GdelaysLeaf1)) > 0
            Nx = find(tFine-obj.GdelaysLeaf1(1)<1e-12,1,'last');
            Ny = find(tFine-obj.GdelaysLeaf1(2)<1e-12,1,'last');
            Nz = find(tFine-obj.GdelaysLeaf1(3)<1e-12,1,'last');
         end

         obj.GxLeaf1 = [zeros(1,Nx) Gsmooth(1:end-Nx)];
         obj.GyLeaf1 = [zeros(1,Ny) Gsmooth(1:end-Ny)];
         obj.GzLeaf1 = [zeros(1,Nz) Gsmooth(1:end-Nz)];

         obj.GxLeaf1 = interp1(tFine, obj.GxLeaf1, t, 'spline', 0);
         obj.GyLeaf1 = interp1(tFine, obj.GyLeaf1, t, 'spline', 0);
         obj.GzLeaf1 = interp1(tFine, obj.GzLeaf1, t, 'spline', 0);

         % figure, plot(GwaveLeaf), hold on, plot(obj.GxLeaf1), plot(obj.GyLeaf1), plot(obj.GzLeaf1), hold off

         thisGx = obj.GxLeaf1'*obj.dirX;
         thisGy = obj.GyLeaf1'*obj.dirY;
         thisGz = obj.GzLeaf1'*obj.dirZ;

         rx = cumsum(obj.gammabar*thisGx.*obj.td,1);
         ry = cumsum(obj.gammabar*thisGy.*obj.td,1);
         rz = cumsum(obj.gammabar*thisGz.*obj.td,1);

         obj.kxLeaf1 = rx(4:round(obj.TencLeaf/2/obj.td)+3,:);
         obj.kyLeaf1 = ry(4:round(obj.TencLeaf/2/obj.td)+3,:);
         obj.kzLeaf1 = rz(4:round(obj.TencLeaf/2/obj.td)+3,:);
      end

      function kSpaceDipolar2(obj)
         leafRampTime = roundUpTenMicroSec(obj.Gleaf/obj.slewRate);
         leafFlatTime = obj.TencLeaf/2-2*leafRampTime;

         NRamp = round(leafRampTime/obj.td);
         NFlat = round(leafFlatTime/obj.td);

         dG = obj.Gleaf/NRamp;
         waveRamp = dG*(1:NRamp);

         waveFlat = obj.Gleaf*ones(1,NFlat);

         GwaveLeaf = [0 0 0 -waveRamp -waveFlat -fliplr(waveRamp) 0 0 0];

         leafN = size(obj.dataLeaf,1)/2;

         if numel(GwaveLeaf) < leafN
            GwaveLeaf = [GwaveLeaf zeros(1,leafN-numel(GwaveLeaf))];
         elseif numel(GwaveLeaf) > leafN
            GwaveLeaf = GwaveLeaf(1:leafN);
         end

         t     = 0:obj.td:leafN*obj.td-obj.td;
         tFine = 0:0.1e-6:leafN*obj.td-obj.td;

         Gsmooth = interp1(t, GwaveLeaf, tFine, 'linear', 'extrap');

         Nx = 0;
         Ny = 0;
         Nz = 0;
         if sum(abs(obj.GdelaysLeaf2)) > 0
            Nx = find(tFine-obj.GdelaysLeaf2(1)<1e-12,1,'last');
            Ny = find(tFine-obj.GdelaysLeaf2(2)<1e-12,1,'last');
            Nz = find(tFine-obj.GdelaysLeaf2(3)<1e-12,1,'last');
         end

         obj.GxLeaf2 = [zeros(1,Nx) Gsmooth(1:end-Nx)];
         obj.GyLeaf2 = [zeros(1,Ny) Gsmooth(1:end-Ny)];
         obj.GzLeaf2 = [zeros(1,Nz) Gsmooth(1:end-Nz)];

         obj.GxLeaf2 = interp1(tFine, obj.GxLeaf2, t, 'spline', 0);
         obj.GyLeaf2 = interp1(tFine, obj.GyLeaf2, t, 'spline', 0);
         obj.GzLeaf2 = interp1(tFine, obj.GzLeaf2, t, 'spline', 0);

         % figure, plot(GwaveLeaf), hold on, plot(obj.GxLeaf2), plot(obj.GyLeaf2), plot(obj.GzLeaf2), hold off

         thisGx = obj.GxLeaf2'*obj.dirX;
         thisGy = obj.GyLeaf2'*obj.dirY;
         thisGz = obj.GzLeaf2'*obj.dirZ;

         rx = cumsum(obj.gammabar*thisGx.*obj.td,1);
         ry = cumsum(obj.gammabar*thisGy.*obj.td,1);
         rz = cumsum(obj.gammabar*thisGz.*obj.td,1);

         rx0 = cumsum(-obj.gammabar*thisGx.*obj.td,1);
         ry0 = cumsum(-obj.gammabar*thisGy.*obj.td,1);
         rz0 = cumsum(-obj.gammabar*thisGz.*obj.td,1);

         ind1 = 5;
         ind2 = round(obj.TencLeaf/2/obj.td)+6;
         obj.kxLeaf2 = rx0(end,:) + rx(ind1:ind2,:);
         obj.kyLeaf2 = ry0(end,:) + ry(ind1:ind2,:);
         obj.kzLeaf2 = rz0(end,:) + rz(ind1:ind2,:);
      end

      function calcHamming(obj)
         a0 = 0.53836;
         a1 = 1-a0;
         M = obj.BR*obj.OS-1;%obj.BR*2-1;
         obj.hamm = a0-a1*cos(2*pi*(0:M)./M);
         obj.hamm = bsxfun(@times,bsxfun(@times,obj.hamm.',obj.hamm),permute(obj.hamm.',[3 2 1]));
         obj.hamm = obj.hamm./(max(obj.hamm,[],'all'));

         fprintf('Hamming filter is calculated.\n')
      end

      function calcHammingLeaf(obj)
         if ~obj.ifWE || obj.Gleaf <= 0
            return
         end
         a0 = 0.53836;
         a1 = 1-a0;
         M = 2*obj.BRleaf-1;
         obj.hammLeaf = a0-a1*cos(2*pi*(0:M)./M);
         obj.hammLeaf = bsxfun(@times,bsxfun(@times,obj.hammLeaf.',obj.hammLeaf),permute(obj.hammLeaf.',[3 2 1]));
         obj.hammLeaf = obj.hammLeaf./(max(obj.hammLeaf,[],'all'));

         fprintf('Hamming filter for leaves is calculated.\n')
      end

      function calcFOV_Shifter(obj)
         offcenterSag = 0;
         offcenterCor = 0;
         offcenterTra = 0;

         offcenterX = 0;
         offcenterY = 0;
         offcenterZ = 0;

         obj.offcenter = 0;

         if isempty(obj.rawdata)
            obj.readData();
         end

         if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation, 'sPosition'))
            if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition, 'dSag'))
               offcenterSag = obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition.dSag*1e-3;
            end
            if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition, 'dCor'))
               offcenterCor = obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition.dCor*1e-3;
            end
            if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition, 'dTra'))
               offcenterTra = obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition.dTra*1e-3;
            end

            switch obj.rawdata.hdr.Dicom.tPatientPosition
               case 'HFS'
                  offcenterX = -offcenterCor;
                  offcenterY = offcenterSag;
                  offcenterZ = -offcenterTra;
               case 'HFP'
                  offcenterX = offcenterCor;
                  offcenterY = -offcenterSag;
                  offcenterZ = -offcenterTra;
               case 'HFDR'
                  offcenterX = offcenterSag;
                  offcenterY = offcenterCor;
                  offcenterZ = -offcenterTra;
               case 'HFDL'
                  offcenterX = -offcenterSag;
                  offcenterY = -offcenterCor;
                  offcenterZ = -offcenterTra;
               case 'FFS'
                  offcenterX = -offcenterCor;
                  offcenterY = -offcenterSag;
                  offcenterZ = offcenterTra;
               case 'FFP'
                  offcenterX = offcenterCor;
                  offcenterY = offcenterSag;
                  offcenterZ = offcenterTra;
               case 'FFDR'
                  offcenterX = offcenterSag;
                  offcenterY = -offcenterCor;
                  offcenterZ = offcenterTra;
               case 'FFDL'
                  offcenterX = -offcenterSag;
                  offcenterY = offcenterCor;
                  offcenterZ = offcenterTra;
            end

            obj.offcenter = sqrt(offcenterCor^2+offcenterSag^2+offcenterTra^2);

            obj.kr = single(linspace(-obj.kmax,obj.kmax-obj.dk,2*obj.BR));
            [krx, kry, krz] = meshgrid(obj.kr,obj.kr,obj.kr);
            obj.kr = exp(-1i*2*pi*(krx*offcenterX+kry*offcenterY+krz*offcenterZ));

            if obj.ifWE && obj.Gleaf > 0
               obj.krLeaf = single(linspace(-obj.kmaxLeaf,obj.kmaxLeaf-obj.dk,obj.BRleaf*2));
               [krx, kry, krz] = meshgrid(obj.krLeaf,obj.krLeaf,obj.krLeaf);
               obj.krLeaf = exp(-1i*2*pi*(krx*offcenterX+kry*offcenterY+krz*offcenterZ));
            end
         else
            obj.kr = 1;
         end

         fprintf('FOV shifter calculated.\n');
      end


% function kr = calcFOV_Shifter_SPI(obj, m)
%          offcenterSag = 0;
%          offcenterCor = 0;
%          offcenterTra = 0;
% 
%          offcenterX = 0;
%          offcenterY = 0;
%          offcenterZ = 0;
% 
%          obj.offcenter = 0;
% 
%          if isempty(obj.rawdata)
%             obj.readData();
%          end
% 
%          if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation, 'sPosition'))
%             if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition, 'dSag'))
%                offcenterSag = obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition.dSag*1e-3;
%             end
%             if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition, 'dCor'))
%                offcenterCor = obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition.dCor*1e-3;
%             end
%             if(isfield(obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition, 'dTra'))
%                offcenterTra = obj.rawdata.hdr.Phoenix.sAAInitialOffset.SliceInformation.sPosition.dTra*1e-3;
%             end
% 
%             switch obj.rawdata.hdr.Dicom.tPatientPosition
%                case 'HFS'
%                   offcenterX = -offcenterCor;
%                   offcenterY = offcenterSag;
%                   offcenterZ = -offcenterTra;
%                case 'HFP'
%                   offcenterX = offcenterCor;
%                   offcenterY = -offcenterSag;
%                   offcenterZ = -offcenterTra;
%                case 'HFDR'
%                   offcenterX = offcenterSag;
%                   offcenterY = offcenterCor;
%                   offcenterZ = -offcenterTra;
%                case 'HFDL'
%                   offcenterX = -offcenterSag;
%                   offcenterY = -offcenterCor;
%                   offcenterZ = -offcenterTra;
%                case 'FFS'
%                   offcenterX = -offcenterCor;
%                   offcenterY = -offcenterSag;
%                   offcenterZ = offcenterTra;
%                case 'FFP'
%                   offcenterX = offcenterCor;
%                   offcenterY = offcenterSag;
%                   offcenterZ = offcenterTra;
%                case 'FFDR'
%                   offcenterX = offcenterSag;
%                   offcenterY = -offcenterCor;
%                   offcenterZ = offcenterTra;
%                case 'FFDL'
%                   offcenterX = -offcenterSag;
%                   offcenterY = offcenterCor;
%                   offcenterZ = offcenterTra;
%             end
% 
%             tempX = offcenterX;
%             tempY = offcenterY;
%             tempZ = offcenterZ;
% 
%             offcenterX = -tempX;
%             offcenterY = tempZ;
%             offcenterZ = 0;
% 
%             obj.offcenter = sqrt(offcenterCor^2+offcenterSag^2+offcenterTra^2);
% 
%             kr = single(linspace(-obj.kmax,obj.kmax-obj.dk,size(m,1)));%warum nicht obj.BR*obj.OS statt m
%             [krx, kry, krz] = meshgrid(kr,kr,kr);
%             kr = exp(-1i*2*pi*(krx*offcenterX+kry*offcenterY+krz*offcenterZ));        
%          end
% 
%          fprintf('FOV shifter SPI calculated.\n');
%       end

      function reconGRE(obj)
         if ~obj.ifDE || ~obj.Nspokes
            return
         end
         fprintf('Gridding and reconstructing...\n');

         %tempMem = memory;
         %tempMem = tempMem.MemAvailableAllArrays/1024^3 > 63;
         if obj.ifComplexOutput %&& tempMem
            obj.ims2 = zeros(obj.BR, obj.BR, obj.BR, obj.numChannels, obj.numMeas, 'single');
         end
         obj.imFinal2 = zeros(obj.OS*obj.BR, obj.OS*obj.BR, obj.OS*obj.BR,obj.numMeas, 'single');

         if obj.ifHamm && isempty(obj.hamm)
            obj.calcHamming;
         end

         for rep = 1:obj.numMeas
            for c = 1:obj.numChannels%determine what channels are recon
               fprintf('Channel %d/%d\n',c,obj.numChannels);

               sigR = squeeze(obj.dataGRE(:, c, :, rep));

               m = gridkb3D(sigR(:),obj.kxR2(:),obj.kyR2(:),obj.kzR2(:), obj.BR, 2, obj.wg)./obj.DCF2;

               m = m.*obj.kr;
               if obj.ifHamm
                  m = m.*obj.hamm;
               end

               im = ifftnS(m);
               obj.imFinal2(:,:,:,rep) = obj.imFinal2(:,:,:,rep) + abs(im).^2;
               if obj.ifComplexOutput %&& tempMem
                  im = remOS(im,1:3,2);
                  obj.ims2(:,:,:,c,rep) = im;
               end
            end
         end

         obj.imFinal2 = sqrt(obj.imFinal2);
      end

      function recon(obj)
         fprintf('Gridding and reconstructing...\n');

         tempMem = memory;
         tempMem = tempMem.MemAvailableAllArrays/1024^3 > 63;
         if obj.ifComplexOutput && tempMem
            obj.ims = zeros(obj.BR, obj.BR, obj.BR, obj.numChannels, obj.numMeas, 'single');
         end
         obj.imFinal = zeros(2*obj.BR, 2*obj.BR, 2*obj.BR, obj.numMeas, 'single');
         if obj.Nspokes
            obj.imFinal = zeros(2*obj.BR, 2*obj.BR, 2*obj.BR, obj.numMeas, 'single');
         end

         if obj.Nspokes == 0
            obj.ims     = zeros(size(obj.dataC,2), size(obj.dataC,3), size(obj.dataC,4), obj.numChannels, obj.numMeas, 'single');
            obj.imFinal = zeros(size(obj.dataC,2), size(obj.dataC,3), size(obj.dataC,4), obj.numMeas, 'single');
         end

         if obj.Acc ~= 1
            if isempty(obj.dataC)
               obj.readData();
               if obj.ifSPI
                  obj.getSPIData();
               end
            end
            scaleM = max(abs(obj.dataC(:)));

            if obj.Nspokes
               obj.imFinalZeroFill = zeros(2*obj.BR, 2*obj.BR, 2*obj.BR, obj.numMeas, 'single');
            else
               obj.imFinalZeroFill = zeros(size(obj.dataC,2), size(obj.dataC,3), size(obj.dataC,4), obj.numMeas, 'single');
            end
         end

         if obj.ifHamm && isempty(obj.hamm)
            obj.calcHamming;
         end

         if numel(obj.dataC) > 0 && obj.Nspokes
            NN = obj.BR+1;
            m_ind = (NN-obj.kgapN):(NN+obj.kgapN);

            [X,Y,Z] = ndgrid(-obj.kgapN:obj.kgapN,-obj.kgapN:obj.kgapN,-obj.kgapN:obj.kgapN);
            R = sqrt(X.^2 + Y.^2 + Z.^2);
         end

         if obj.Acc > 1
            if obj.Nspokes
               sensMaps = ones(2*obj.BR,2*obj.BR,2*obj.BR,'single');
            else
               sensMaps = ones(size(obj.dataC,2),size(obj.dataC,3),size(obj.dataC,4),'single');
            end

            comm = 'pics';
            % if gpuDeviceCount
            %    temp = gpuDevice;
            %    if contains(temp.Name,'RTX') && temp.TotalMemory/(1024^3) > 16 && temp.TotalMemory/(1024^3) > 16 && (obj.BR*2) < 512
            %       comm = strcat(comm, ' -g');
            %    end
            % end
            comm = strcat(comm,' -g -d4 -u0.01 -S -i',num2str(obj.ADMM_iter), ' -R I:0:',num2str(obj.lambdal1),' -R T:7:0:',num2str(obj.lambdaTV));
         end

         for rep = 1:obj.numMeas
            if obj.numMeas > 1
               fprintf('Measurement %d/%d\n',rep,obj.numMeas);
            end
            for c = 1:obj.numChannels
               fprintf('Channel %d/%d\n',c,obj.numChannels);

               if obj.Nspokes
                  sigR = squeeze(obj.dataR(:, c, :, rep));

                  mr = gridkb3D(sigR(:),obj.kxR(:),obj.kyR(:),obj.kzR(:), obj.BR, 2, obj.wg)./obj.DCF;
               end

               if numel(obj.dataC) > 0
                  if obj.Nspokes
                     m  = mr;
                     mCenter = m(m_ind,m_ind,m_ind);
                     if obj.spiTE <= obj.TE + 5*obj.td
                        sigC = squeeze(obj.spiData(:,:,c,rep));
                        mc = gridkb3D(sigC(:),obj.kxC(:),obj.kyC(:),obj.kzC(:), obj.BR, 2, obj.wg)./obj.DCF_SPI;
                        mc = mc(m_ind,m_ind,m_ind);
                     else
                        mc = squeeze(obj.dataC(1,:,:,:,c,rep));
                     end
                     mCenter(R <= obj.kgapN) = mc(R <= obj.kgapN);

                     m(m_ind,m_ind,m_ind) = mCenter;
                  else
                     m = squeeze(obj.dataC(1,:,:,:,c,rep));
                  end
               else
                  m = mr;
               end

               if obj.Nspokes
                   m = m.*obj.kr;
                   if obj.ifHamm
                       m = m.*obj.hamm;
                   end
               end
% obj.Acc
               if obj.Acc == 1                 
                  im = ifftnS(m);
               else
                  im = bart7(obj.BART_Path, comm, m/scaleM, sensMaps)*scaleM;

                  imZeroFill = ifftnS(m);

                  obj.imFinalZeroFill(:,:,:,rep) = obj.imFinalZeroFill(:,:,:,rep) + abs(imZeroFill).^2;
               end
               obj.imFinal(:,:,:,rep) = obj.imFinal(:,:,:,rep) + abs(im).^2;
              
               if obj.ifComplexOutput %&& tempMem
                  if obj.Nspokes 
                    im = remOS(im,1:3,obj.OS);
                  end
                  % obj.ims(:,:,:,c,rep) = im;
                  % TE = num2str(obj.TE*10^6);
                  % fname = strcat('Stryker_',TE,'_',num2str(c),'.mat');
                  % path = fullfile('FieldMap/Stryker',fname);
                  % Vi = squeeze(im(180,:,:));
                  % Vi = rot90(Vi,-1);
                  % save(path,'Vi');
               end
               clear sigR sigC m mr im imZeroPad
            end
         end
         kw = obj.wg/obj.OS;
         beta = pi * sqrt((kw * (obj.OS - 0.5))^2 - 0.8);
         depo = deapodFilter_3D_1(kw,beta,obj.OS,obj.BR);
         obj.imFinal = sqrt(obj.imFinal)./abs(depo);         
      end



      function reconLeaf1(obj)
         if ~obj.ifWE || obj.Gleaf <= 0
            return
         end
         fprintf('Reconstructing Leaf-1...\n');

         if mod(obj.BRleaf,4) == 0
            obj.imsLeaf1 = zeros(obj.BRleaf, obj.BRleaf, obj.BRleaf, obj.numChannels, obj.numMeas,'single');
         else
            obj.imsLeaf1 = zeros(2*obj.BRleaf, 2*obj.BRleaf, 2*obj.BRleaf, obj.numChannels, obj.numMeas,'single');
         end
         obj.imFinalLeaf1 = zeros(2*obj.BRleaf, 2*obj.BRleaf, 2*obj.BRleaf, obj.numMeas,'single');

         if isempty(obj.krLeaf)
            obj.calcFOV_Shifter();
         end

         for rep = 1:obj.numMeas
            if obj.numMeas > 1
               fprintf('Measurement %d/%d\n',rep,obj.numMeas);
            end
            for c = 1:obj.numChannels%determine what channels are recon
               fprintf('Channel %d/%d.\n', c, obj.numChannels);

               if obj.ifLeaf
                  ind1 = 8;
                  ind2 = size(obj.kxLeaf1,1) + ind1 - 1;

                  sig = squeeze(obj.dataLeaf(ind1:ind2, c, :, rep));
               else
                  ind1 = 4;
                  ind2 = size(obj.kxLeaf1,1) + ind1 - 1;
                  sig = squeeze(obj.dataLeaf(ind1:ind2, c, :, rep));
               end

               m = gridkb3D(sig(:),obj.kxLeaf1(:),obj.kyLeaf1(:),obj.kzLeaf1(:), obj.BRleaf, 2, obj.wg)./obj.DCFleaf1;
               m = m.*obj.krLeaf;

               if obj.ifHamm
                  m = m.*obj.hammLeaf;
               end

               im = ifftnS(m);

               obj.imFinalLeaf1(:,:,:,rep) = obj.imFinalLeaf1(:,:,:,rep) + abs(im).^2;

               if mod(obj.BRleaf,4) == 0
                  im = remOS(im,1:3,2);
               end

               obj.imsLeaf1(:,:,:,c,rep) = im;

               clear m im sig;
            end
         end

         obj.imFinalLeaf1 = sqrt(obj.imFinalLeaf1);
      end

      function reconLeaf2(obj)
         if ~obj.ifWE || obj.Gleaf <= 0
            return
         end
         fprintf('Reconstructing Leaf-2...\n');

         if mod(obj.BRleaf,4) == 0
            obj.imsLeaf2 = zeros(obj.BRleaf, obj.BRleaf, obj.BRleaf, obj.numChannels, obj.numMeas,'single');
         else
            obj.imsLeaf2 = zeros(2*obj.BRleaf, 2*obj.BRleaf, 2*obj.BRleaf, obj.numChannels, obj.numMeas,'single');
         end
         obj.imFinalLeaf2 = zeros(2*obj.BRleaf, 2*obj.BRleaf, 2*obj.BRleaf, obj.numMeas,'single');

         if isempty(obj.krLeaf)
            obj.calcFOV_Shifter();
         end

         for rep = 1:obj.numMeas
            if obj.numMeas > 1
               fprintf('Measurement %d/%d\n',rep,obj.numMeas);
            end
            for c = 1:obj.numChannels%determine what channels are recon
               fprintf('Channel %d/%d.\n', c, obj.numChannels);

               if obj.ifLeaf
                  ind1 = size(obj.kxLeaf1,1) + 6;
                  ind2 = ind1 + size(obj.kxLeaf2,1) - 1;

                  sig = squeeze(obj.dataLeaf(ind1:ind2, c, :, rep));
               else
                  ind1 = (obj.Nleaf-10)/2 - 1;
                  ind2 = size(obj.kxLeaf2,1) + ind1 - 1;

                  sig = squeeze(obj.dataLeaf(ind1:ind2, c, :, rep));
               end

               m = gridkb3D(sig(:),obj.kxLeaf2(:),obj.kyLeaf2(:),obj.kzLeaf2(:), obj.BRleaf, 2, obj.wg)./obj.DCFleaf2;
               m = m.*obj.krLeaf;
               if obj.ifHamm
                  m = m.*obj.hammLeaf;
               end
               im = ifftnS(m);

               obj.imFinalLeaf2(:,:,:,rep) = obj.imFinalLeaf2(:,:,:,rep) + abs(im).^2;

               if mod(obj.BRleaf,4) == 0
                  im = remOS(im,1:3,2);
               end

               obj.imsLeaf2(:,:,:,c,rep) = im;

               clear m im sig;
            end
         end

         obj.imFinalLeaf2 = sqrt(obj.imFinalLeaf2);
      end

      function saveObj(obj)
         fprintf('Saving object...\n')
         foldName = strcat(obj.dirName, obj.fileno, '\');
         temp = strcat(foldName, obj.fileno, 'obj', '.mat');

         obj.rawdata = [];
         obj.dataR = [];
         obj.dataGRE = [];
         obj.dataC = [];
         obj.spiData = [];
         obj.kxR = [];
         obj.kyR = [];
         obj.kzR = [];
         obj.kxR2 = [];
         obj.kyR2 = [];
         obj.kzR2 = [];
         obj.kr = [];
         obj.hamm = [];
         obj.DCF = [];
         obj.Gwave = [];
         obj.Gx = [];
         obj.Gy = [];
         obj.Gz = [];

         save(temp,'obj','-v7.3');

         fprintf('Object is saved.\n')
      end

      function correctOrientations(obj)
         % Not finished yet
         switch obj.rawdata.hdr.Dicom.tPatientPosition
            case 'HFS'
               if ~isempty(obj.imFinal)
                  obj.imFinal  = imrotate3(obj.imFinal,-90,[0 0 1]);
               end
               if ~isempty(obj.imFinal2)
                  obj.imFinal2 = imrotate3(obj.imFinal2,-90,[0 0 1]);
               end

               if ~isempty(obj.imFinalLeaf1)
                  obj.imFinalLeaf1  = imrotate3(obj.imFinalLeaf1,-90,[0 0 1]);
               end
               if ~isempty(obj.imFinalLeaf2)
                  obj.imFinalLeaf2  = imrotate3(obj.imFinalLeaf2,-90,[0 0 1]);
               end
            case 'HFP'

            case 'HFDR'

            case 'HFDL'

            case 'FFS'
               if ~isempty(obj.imFinal)
                  obj.imFinal = imrotate3(obj.imFinal,90,[0 0 1]);
                  obj.imFinal = imrotate3(obj.imFinal,180,[1 0 0]);
               end
               if ~isempty(obj.imFinal2)
                  obj.imFinal2 = imrotate3(obj.imFinal2,90,[0 0 1]);
                  obj.imFinal2 = imrotate3(obj.imFinal,180,[1 0 0]);
               end

               if ~isempty(obj.imFinalLeaf1)
                  obj.imFinalLeaf1 = imrotate3(obj.imFinalLeaf1,90,[0 0 1]);
                  obj.imFinalLeaf1 = imrotate3(obj.imFinalLeaf1,180,[1 0 0]);
               end
               if ~isempty(obj.imFinalLeaf2)
                  obj.imFinalLeaf2 = imrotate3(obj.imFinalLeaf2,90,[0 0 1]);
                  obj.imFinalLeaf2 = imrotate3(obj.imFinalLeaf2,180,[1 0 0]);
               end
            case 'FFP'

            case 'FFDR'

            case 'FFDL'

            otherwise
               fprintf('Patient is centered')
         end
      end




      function dicomWrite(obj,echo,measID)
         foldName    = strcat(obj.dirName, obj.fileno, '\');
  
         fname       = strcat(foldName,obj.fileno);
         
         if strcmp(obj.rawdata.hdr.Phoenix.tSequenceFileName, "%CustomerSeq%\xte")
            fname = strcat(fname,'_xte');
         elseif strcmp(obj.rawdata.hdr.Phoenix.tSequenceFileName, "%CustomerSeq%\si_petra")
            fname = strcat(fname,'_si_petra');
         else
            fname = strcat(fname,'_UnknownSequence');
         end

         switch echo
            case 'ZTE'
               V = abs(obj.imFinal(:,:,:,measID));
               if obj.Nspokes
                  V = remOS(V,1:3,obj.gridOS);%careful only remove less in case of smaller fov
               end
            case 'GRE'
               V = abs(obj.imFinal2(:,:,:,measID));
               if obj.Nspokes
                  V = remOS(V);
               end
               fname = strcat(fname,'_DE');
            case 'SUBS'
               V = abs(obj.imFinal(:,:,:,measID)) - abs(obj.imFinal2(:,:,:,measID));
               V = remOS(V);
               if min(V(:)) < 0
                  V = V - min(V(:));
               end
               fname = strcat(fname,'_Subs');
            case 'Leaf1'
               V = abs(obj.imFinalLeaf1(:,:,:,measID));
               if mod(obj.BRleaf,4) == 0
                  V = remOS(V);
               end
               fname = strcat(fname,'_Leaf1');
            case 'Leaf2'
               V = abs(obj.imFinalLeaf2(:,:,:,measID));
               if mod(obj.BRleaf,4) == 0
                  V = remOS(V);
               end
               fname = strcat(fname,'_Leaf2');
            case 'ZeroFill'
               V = abs(obj.imFinalZeroFill(:,:,:,measID));
               if obj.Nspokes
                  V = remOS(V,1:3,2);
               end
               fname = strcat(fname,'_ZeroPad');
         end

         fname = strcat(fname,datestr(now,'_ddmmyyyy_HHMM'));

         if obj.ifWE
            fname = strcat(fname,'_WaterExc');
         end
         if obj.ifFS
            fname = strcat(fname,'_CHESS');
         end
         if obj.ifIR
            fname = strcat(fname,'_Inv_TI_',num2str(obj.TI*1e3));
         end
         if obj.ifHamm
            fname = strcat(fname,'_HammFilt');
         end

         if or(obj.Acc > 1, obj.aAcc > 1)
            fname = strcat(fname,'_Acc_',num2str(obj.Acc),'_l1_',num2str(obj.lambdal1),'_TV_',num2str(obj.lambdaTV));
         end

         if obj.numMeas > 1
            fname = strcat(fname,'_measNo_',num2str(measID));
         end

         scaleFactor = max(V(:));
         V = V/scaleFactor;

         fname = strcat(fname,'_Scale_',num2str(scaleFactor));

         VS = obj.dr*1e3;
         seriesNo = str2double(obj.fileno);
         lastName = 'Volunteer';
         firstName = 'Anonymized';
         sequenceName = 'si_petra';
         patientID = '100';
         studyID = obj.fileno;

         if numel(VS)==1
            VS = [VS(1) VS(1) VS(1)];
         end
         if numel(VS) ~= 3
            error('VS needs to be either a scalar or 3-d vector.');
         end

         load('sampleDICOMheader.mat'); %#ok<LOAD>

         rng shuffle

         temp  = strcat('1.3.12.2.1107.5.2.43.67024.20201230',num2str(randi(1000000)));
         temp2 = strcat('1.3.12.2.1107.5.2.43.67024.20201230',num2str(randi(1000000)));
         temp3 = strcat('1.3.12.2.1107.5.2.43.67024.20201230',num2str(randi(1000000)));
         temp4 = strcat('1.3.12.2.1107.5.2.43.67024.20201230',num2str(randi(1000000)));

         info.ImagerPixelSpacing = VS(1:2);

         info.PatientBirthDate = '20220610';

         info.FileModDate = datestr(now);
         info.Width = size(V,1);
         info.Height = size(V,2);
         info.MediaStorageSOPInstanceUID = temp;
         info.InstanceCreationDate = datestr(now,'yyyymmdd');
         info.InstanceCreationTime = datestr(now,'hhdd');
         info.SOPInstanceUID = temp;
         info.StudyDate = datestr(now,'yyyymmdd');
         info.SeriesDate = datestr(now,'yyyymmdd');
         info.AcquisitionDate = datestr(now,'yyyymmdd');
         info.ContentDate = datestr(now,'yyyymmdd');
         info.StudyDescription = fname(find(fname=='\',1,'last')+1:end);
         info.StudyDescription = info.StudyDescription(1:find(info.StudyDescription =='_',2,'last')-1);
         info.SeriesDescription = sequenceName;
         info.PatientName.FamilyName = lastName;
         info.PatientName.GivenName = firstName;
         info.PatientID = patientID;
         info.PatientSize = 2;
         info.PatientWeight = 100;
         if numel(obj.rawdata)
            info.BodyPartExamined = obj.rawdata.hdr.Dicom.tBodyPartExamined;
         else
            info.BodyPartExamined = 'WHOLEBODY';
         end
         info.ScanningSequence = 'RM';
         info.SequenceName = sequenceName;
         info.SliceThickness = VS(3);
         info.RepetitionTime = obj.TR*1e3;
         info.EchoTime = obj.TE*1e3;

         if obj.ifDE
            info.EchoNumbers = 2;
         else
            info.EchoNumbers = 1;
         end
         info.NumberOfPhaseEncodingSteps = obj.Nspokes;
         info.PixelBandwidth = 1/(2*obj.Tenc);
         info.ProtocolName = sequenceName;
         info.AcquisitionMatrix = [0;size(V,1);size(V,2);0];
         info.FlipAngle = obj.FA;
         info.PatientPosition = obj.rawdata.hdr.Dicom.tPatientPosition;
         info.StudyInstanceUID = temp4;
         info.SeriesInstanceUID = temp2;
         info.StudyID = studyID;
         info.SeriesNumber = seriesNo;
         info.ImageOrientationPatient = [1 0 0 0 1 0];
         info.FrameOfReferenceUID = temp3;
         info.Rows = size(V,1);
         info.Columns = size(V,2);
         info.PixelSpacing = VS(1:2);

         if ~exist(fname, 'dir')
            mkdir(fname);
         end

         for i=1:size(V,3)
            cfn = strcat(fname,sprintf('\\img_%d.dcm', i));
            info.Filename = cfn;

            I = im2uint8(squeeze(V(:,:,i)));

            info.InstanceNumber = i;
            info.SliceLocation = i*VS(3);
            info.ImagePositionPatient = [0 0 i*VS(3)];
            dicomwrite(I, cfn, info);
         end
      end

      function niftiWrite(obj,echo)
         foldName    = strcat(obj.dirName, obj.fileno, '\');
         fname       = strcat(foldName,obj.fileno);

         fname = strcat(fname,'_xte');

         switch echo
            case 'ZTE'
               if ~obj.ifComplexOutput
                  V = obj.imFinal;
               else
                  V = obj.ims;
               end
               if obj.Nspokes && mod(obj.BR,4) == 0 && ~obj.ifComplexOutput
                  V = remOS(V,1:3,obj.OS);
               end
            case 'GRE'
               if ~obj.ifComplexOutput
                  V = obj.imFinal2;
               else
                  V = obj.ims2;
               end
               if obj.Nspokes && mod(obj.BR,4) == 0 && ~obj.ifComplexOutput
                  V = remOS(V,1:3,obj.OS);
               end
               fname = strcat(fname,'_DE');
            case 'SUBS'
               V = abs(obj.imFinal) - abs(obj.imFinal2);
               if obj.Nspokes && mod(obj.BR,4) == 0
                  V = remOS(V,1:3,obj.OS);
               end
               fname = strcat(fname,'_Subs');
            case 'Leaf1'
               if ~obj.ifComplexOutput
                  V = obj.imFinalLeaf1;
               else
                  V = obj.imsLeaf1;
               end
               if mod(obj.BRleaf,4) == 0 && ~obj.ifComplexOutput
                  V = remOS(V,1:3,obj.OS);
               end
               fname = strcat(fname,'_Leaf1');
            case 'Leaf2'
               if ~obj.ifComplexOutput
                  V = obj.imFinalLeaf2;
               else
                  V = obj.imsLeaf2;
               end
               if mod(obj.BRleaf,4) == 0 && ~obj.ifComplexOutput
                  V = remOS(V,1:3,obj.OS);
               end
               fname = strcat(fname,'_Leaf2');
            case 'ZeroFill'
               if obj.Nspokes && mod(obj.BR,4) == 0
                  V = remOS(obj.imFinalZeroFill,1:3,obj.OS);
               end
               fname = strcat(fname,'_ZeroPad');
            case 'Merged'
               V = obj.imFinalMerged;
               if obj.Nspokes && mod(obj.BR,4) == 0
                  V = remOS(V,1:3,2);
               end
               fname = strcat(fname,'_Merged');
         end

         fname = strcat(fname,datestr(now,'_ddmmyyyy_HHMM'));

         if obj.ifWE
            fname = strcat(fname,'_WaterExc');
         end
         if obj.ifFS
            fname = strcat(fname,'_CHESS');
         end
         if obj.ifIR
            fname = strcat(fname,'_Inv_TI_',num2str(obj.TI*1e3));
         end
         if obj.ifHamm
            fname = strcat(fname,'_HammFilt');
         end

         if obj.ifComplexOutput
            fname2 = fname;
            fname2 = strcat(fname2,'_phase.nii');
         end

         fname = strcat(fname,'.nii');

         info = struct;
         info.Filename = fname;
         info.Filemoddate = datestr(datetime('now'));
         info.Version = 'NIfTI1';
         info.Description = '';
         info.ImageSize = size(V);
         switch echo
            case 'ZTE'
               info.PixelDimensions = obj.dr*[1 1 1];
            case 'GRE'
               info.PixelDimensions = obj.dr*[1 1 1];
            case 'SUBS'
               info.PixelDimensions = obj.dr*[1 1 1];
            case 'Leaf1'
               info.PixelDimensions = obj.drLeaf*[1 1 1];
            case 'Leaf2'
               info.PixelDimensions = obj.drLeaf*[1 1 1];
            case 'ZeroFill'
               info.PixelDimensions = obj.dr*[1 1 1];
            case 'Merged'
               info.PixelDimensions = obj.dr*[1 1 1];
         end
         info.Datatype = 'single';
         info.BitsPerPixel = 16;
         info.SpaceUnits = 'Unknown';
         info.TimeUnits = 'None';
         info.AdditiveOffset = 0;
         info.MultiplicativeScaling = 0;
         info.TimeOffset = 0;
         info.SliceCode = 'Unknown';
         info.FrequencyDimension = 0;
         info.PhaseDimension = 0;
         info.SpatialDimension = 3;
         info.DisplayIntensityRange = [0 0];
         info.TransformName = 'None';
         info.Qfactor = 1;

         
         if obj.ifComplexOutput
            niftiwrite(abs(V), fname, info);

            info.Filename = fname2;
            niftiwrite(angle(V), fname2, info);
         else
            niftiwrite(V, fname, info);
         end
      end

      function textParams(obj)
         foldName = strcat(obj.dirName, obj.fileno, '\');
         if ~exist(foldName,'dir')
            mkdir(foldName)
         end

         fileName = sprintf('%s%s_Params.txt',foldName,obj.fileno);
         file = fopen(fileName,'w+');
         if file == -1
            fprintf('File can not be opened\n');
            return;
         end

         fprintf(file, '%22s\n\n', fileName);
         fprintf(file, '%22s:\n\n', 'Parameters');

         fprintf(file, '%22s:%7.1f\tcm\n',   'FOV',obj.FOV*100);
         fprintf(file, '%22s:%7d\n',         'BR', obj.BR);
         fprintf(file, '%22s:%7.2f\tmm\n',   'dr', obj.dr*1000);

         fprintf(file, '%22s:%7.0f\tus\n',   'TE',       obj.TE*1e6);
         fprintf(file, '%22s:%7.0f\tus\n\n', 'spiTE',    obj.spiTE*1e6);

         fprintf(file, '%22s:%7.0f\tus\n',   'Tenc',     obj.Tenc*1e6);
         fprintf(file, '%22s:%7.0f\tus\n\n', 'TencLeaf', obj.TencLeaf*1e6);

         fprintf(file, '%22s:%7.1f\tms\n',   'TR', obj.TR*1e3);
         fprintf(file, '%22s:%7.1f\t%c\n\n', 'FA', obj.FA,176);

         fprintf(file, '%22s:%7d\n', '# of spokes', obj.Nspokes);

         fprintf(file, '%22s:%7d\n\n', 'kgapN', obj.kgapN);

         fprintf(file, '%22s:%7d\tus\n',    'Tp', obj.taup*1e6);
         fprintf(file, '%22s:%7d\tns\n\n',  'td', round(obj.td*1e9));

         fprintf(file, '%22s:%7.1f\tmT/m\n',         'Grf',          obj.Grf*1e3);
         fprintf(file, '%22s:%7.1f\tmT/m\n',         'G',            obj.G*1e3);
         fprintf(file, '%22s:%7.1f\tmT/m\n',         'Gleaf',        obj.Gleaf*1e3);
         fprintf(file, '%22s:%7.1f\tmT/m/ms\n\n',    'Slew rate',    obj.slewRate);

         fprintf(file, '%22s:%7d\n',     'Silent',   obj.ifSilent);
         fprintf(file, '%22s:%7d\n\n',   'Spoiling', obj.ifSpoil);

         fprintf(file, '%22s:%7d\n\n', 'DoubleEcho', obj.ifDE);

         if obj.ifMagPrep
            fprintf(file, '%22s:%7d\tTR\n', 'Segmentation', obj.fsPeriod);
         end
         fprintf(file, '%22s:%7d\n', 'IR', obj.ifIR);
         if obj.ifIR
            fprintf(file, '%22s:%7.1f\tms\n', 'TI', obj.TI*1e3);
         end
         fprintf(file, '%22s:%7d\n', 'CHESS',    obj.ifFS);
         fprintf(file, '%22s:%7d\n', '1-1',      obj.ifWE);
         fprintf(file, '%22s:%7d\n', 'ifLeaf',   obj.ifLeaf);
         fprintf(file, '\n');

         fprintf(file, '%22s:%7.1f\n', 'Acc',    obj.Acc);
         fprintf(file, '%22s:%7.1f\n', 'aAcc',    obj.aAcc);
         fprintf(file, '%22s:%7d\n\n', 'Ncalib', obj.Ncalib);

         fprintf(file, '%29s:\n',        'Recon. Parameters');
         fprintf(file, '%22s:%7d\n',     'wg',       obj.wg);
         fprintf(file, '%22s:%7d\n\n',   'hamming',  obj.ifHamm);

         fprintf(file, '%22s:%7.2f\tcm\n\n', 'Isocenter distance', obj.offcenter*100);

         status = fclose(file);
         if status == -1
            fprintf('File cannot be closed!\n');
         end
      end

   end
end