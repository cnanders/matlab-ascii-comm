[cDirThis, cName, cExt] = fileparts(mfilename('fullpath'));
cDirSrc = fullfile(cDirThis,  '..', 'src');
addpath(genpath(cDirSrc));

comm = srs.SR570();
comm.init()
comm.connect()

comm.setSensitivity(3);
comm.disconnect();