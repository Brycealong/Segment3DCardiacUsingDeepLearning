function preprocessCTDataset(destination,source)
% Crop the data set to a region containing primarily the left ventricle and
% left atrium.
% Then, normalize by subtracting the mean and dividing by the standard
% deviation of the cropped brain region. Finally, split the data set into
% training, validation and test sets.

%% Load data
imgPath = fullfile(source, 'imagesTs');
laPath = fullfile(source, 'LA-labelsTs');
lvPath = fullfile(source, 'LV-labelsTs');

% If the directories for preprocessed data does not exist, create the
% directories
if ~exist(destination,'dir')
    mkdir(fullfile(destination,'imagesTr'));
    mkdir(fullfile(destination,'labelsTr'));

    mkdir(fullfile(destination,'imagesVal'));
    mkdir(fullfile(destination,'labelsVal'));

    mkdir(fullfile(destination,'imagesTest'));
    mkdir(fullfile(destination,'labelsTest'));
end

imgFiles = dir(fullfile(imgPath, '*.nii.gz'));

% Randomize file order
rng(42); % For reproducibility
randIdx = randperm(length(imgFiles));
imgFiles = imgFiles(randIdx);

% If none or only a partial set of the data files have been processed,
% process the data.
if proceedWithPreprocessing(destination)
    for i = 1:length(imgFiles)
        filename = imgFiles(i).name;

        % Load data
        img = niftiread(fullfile(imgPath, filename));
        laLabel = niftiread(fullfile(laPath, filename));
        lvLabel = niftiread(fullfile(lvPath, filename));

        % Create combined labels
        combinedLabel = zeros(size(laLabel));
        combinedLabel(laLabel > 0) = 1;
        combinedLabel(lvLabel > 0) = 2;

        foregroundMask = combinedLabel > 0;

        % Get bounding boxes
        props = regionprops3(foregroundMask, 'BoundingBox');
        bbox = ceil(props.BoundingBox(1,:));

        padZ = 8;
        startZ = max(1, bbox(3) - padZ);
        endZ = min(size(img,3), bbox(3) + bbox(6) + padZ);

        % Apply cropping
        cropVol = img(:, :, startZ:endZ);
        cropLabel = combinedLabel(:, :, startZ:endZ);

        % Make size multiple of 8
        newSize = floor(size(cropVol)/8) * 8;
        cropVol = cropVol(1:newSize(1), 1:newSize(2), 1:newSize(3));
        cropLabel = cropLabel(1:newSize(1), 1:newSize(2), 1:newSize(3));

        % Normalization (min max)
        cropVol = mat2gray(cropVol);
        cropVol = single(cropVol);
        cropLabel = uint8(cropLabel);

        % Split into train/val/test
        if i <= floor(0.7 * length(imgFiles))
            imgDir = fullfile(destination, 'imagesTr');
            lblDir = fullfile(destination, 'labelsTr');
        elseif i <= floor(0.9 * length(imgFiles))
            imgDir = fullfile(destination, 'imagesVal');
            lblDir = fullfile(destination, 'labelsVal');
        else
            imgDir = fullfile(destination, 'imagesTest');
            lblDir = fullfile(destination, 'labelsTest');
        end

        % Save with original filename structure
        [~, baseName, ~] = fileparts(imgFiles(i).name);
        baseName = strrep(baseName, '.nii', ''); % Remove .nii if present

        save(fullfile(imgDir, [baseName '.mat']), 'cropVol');
        save(fullfile(lblDir, [baseName '.mat']), 'cropLabel');
    end
end

function out = proceedWithPreprocessing(destination)
    totalNumFiles = 74;
    numFiles = 0;
    if exist(fullfile(destination,'imagesTr'),'dir')
        tmp1 = dir(fullfile(destination,'imagesTr'));
        numFiles = numFiles + sum(~vertcat(tmp1.isdir));
    end

    if exist(fullfile(destination,'imagesVal'),'dir')
        tmp1 = dir(fullfile(destination,'imagesVal'));
        numFiles = numFiles + sum(~vertcat(tmp1.isdir));
    end

    if exist(fullfile(destination,'imagesTest'),'dir')
        tmp1 = dir(fullfile(destination,'imagesTest'));
        numFiles = numFiles + sum(~vertcat(tmp1.isdir));
    end

    % If total number of preprocessed files is not equal to the number of
    % files in the dataset, perform preprocessing. Otherwise, preprocessing has
    % already been completed and can be skipped.
    out = (numFiles ~= totalNumFiles);
end
end