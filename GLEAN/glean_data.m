function GLEAN = glean_data(GLEAN)
% Set up the directory structure for a new or existing GLEAN analysis
%
% GLEAN = glean_data(GLEAN)

GLEANdir = fileparts(GLEAN.name);

% Check beamformed data exists and is in the right format
if ~isfield(GLEAN,'data')            || ... 
   ~isstruct(GLEAN.data)             || ...
   ~isfield(GLEAN.data,'beamformed') || ...
   ~all(cellfun(@ischar,{GLEAN.data.beamformed}))
    error('Must specify GLEAN.data as a [sessions x 1] struct array with field "beamformed"')
end
        
[~,sessionNames] = cellfun(@fileparts,{GLEAN.data.beamformed},'UniformOutput',0);

%% ENVELOPE
% Setup sub directory for envelopes "envelope_R[fsample]_L[log]_F[f1l-f1h_f2l-f2h]"
dirStr = sprintf('%s%s%d%s%d%s%s','envelope', ...
                 '_L',GLEAN.settings.envelope.log, ...
                 '_R',GLEAN.settings.envelope.fsample);
                 
if isfield(GLEAN.settings.envelope,'freqbands');
    dirStr = [dirStr '_F',fbandstr(GLEAN.settings.envelope.freqbands)];
end
             
envelopeDir = fullfile(GLEANdir,dirStr);
envelopeData = fullfile(envelopeDir,'data',strcat(sessionNames,'.mat'));
[GLEAN.data.enveloped] = deal(envelopeData{:});
if ~isdir(envelopeDir)
    mkdir(envelopeDir);
end


%% SUBSPACE
% Setup sub directory for subspace "[method]_$[method_setting1]_$[method_setting2]_..."
switch char(intersect(fieldnames(GLEAN.settings.subspace),{'pca','parcellation','voxel'}))
    case 'pca'
        dirStr = sprintf('%s%s%d%s%d%s%s','pca','_D',GLEAN.settings.subspace.pca.dimensionality, ... 
                                                '_W',GLEAN.settings.subspace.pca.whiten, ...
                                                '_N',GLEAN.settings.subspace.normalisation(1));
    case 'parcellation'  
        [~,parcellation_fname,~] = fileparts(GLEAN.settings.subspace.parcellation.file);
        parcellation_fname = strrep(parcellation_fname,'.nii','');
        dirStr = sprintf('%s%s%s%s%s%s',parcellation_fname,'_M',GLEAN.settings.subspace.parcellation.method(1), ...
                                                           '_N',GLEAN.settings.subspace.normalisation(1));
    case 'voxel'
        dirStr = sprintf('%s%s%s','voxel','_N',GLEAN.settings.subspace.normalisation(1));
end

subspaceDir = fullfile(envelopeDir,dirStr);
subspaceData = fullfile(subspaceDir,'data',strcat(sessionNames,'.mat'));
[GLEAN.data.subspace] = deal(subspaceData{:});
if ~isdir(subspaceDir)
    mkdir(subspaceDir);
end


%% MODEL
% Setup sub directory for model "[method]_$[method_setting1]_$[method_setting2]_..."
switch lower(char(fieldnames(GLEAN.settings.model)))
    case 'hmm'
        dirStr = sprintf('%s%s%d','hmm','_K',GLEAN.settings.model.hmm.nstates);
    case 'ica'
        dirStr = sprintf('%s%s%d','ica','_O',GLEAN.settings.model.ica.order);
end
modelDir = fullfile(subspaceDir,dirStr);
GLEAN.model = fullfile(modelDir,'model.mat');
if ~isdir(modelDir)
    mkdir(modelDir);
end


%% OUTPUT
% Setup sub directory for each output "[method]_$[method_setting1]_$[method_setting2]_..."
if ~isempty(fieldnames(GLEAN.settings.output))
    for field = fieldnames(GLEAN.settings.output)'
        
        output = char(field);
        
        dirStr = sprintf('%s',output);
        outputDir = fullfile(modelDir,dirStr);
        
        switch output
            case 'pcorr'
                sessionMaps = fullfile(outputDir,strcat(sessionNames,'_',output));
                groupMaps   = fullfile(outputDir,strcat('group_',output));
            case 'connectivity_profile'
                sessionMaps = '';
                groupMaps   = fullfile(outputDir,strcat('group_',output));
        end
        
        % Duplicate maps across each frequency band:
        if isfield(GLEAN.settings.envelope,'freqbands')
            fstr      = cellfun(@(s) regexprep(num2str(s),'\s+','-'), GLEAN.settings.envelope.freqbands,'UniformOutput',0);
            groupMaps = strcat(groupMaps,'_',fstr,'Hz.',GLEAN.settings.output.(output).format);
            if ~isempty(sessionMaps)
                sessionMaps = cellfun(@(s) strcat(s,'_',fstr,'Hz.',GLEAN.settings.output.(output).format),sessionMaps,'UniformOutput',0);
            end
        else
            if ~isempty(sessionMaps)
                sessionMaps = cellfun(@(s) {strcat(s,'.',GLEAN.settings.output.(output).format)},sessionMaps,'UniformOutput',0);
            end
            groupMaps = {strcat(groupMaps,'.',GLEAN.settings.output.(output).format)}; 
        end
        
        GLEAN.output.(output).sessionmaps  = sessionMaps;
        GLEAN.output.(output).groupmaps    = groupMaps;
        
        
        if ~isdir(outputDir)
            mkdir(outputDir);
        end
        
    end
end


end

function str = fbandstr(fbands)

tmpstr = regexp(num2str(cat(2,fbands{:})),'\s+','split');
str = cell(1,length(tmpstr)*2 - 1);
str(1:4:end) = tmpstr(1:2:end);
str(3:4:end) = tmpstr(2:2:end);
[str{2:4:end}] = deal('-');
[str{cellfun(@isempty,str)}] = deal('_');
str = [str{:}];

end