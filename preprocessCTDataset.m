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

id = 1;
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
    
    img = double(img);

    foregroundMask = combinedLabel > 0;
    foregroundValues = img(foregroundMask);
    p0_5 = prctile(foregroundValues, 0.5);
    p99_5 = prctile(foregroundValues, 99.5);
    meanVal = mean(foregroundValues);
    stdVal = std(foregroundValues);

    img = max(img, p0_5);
    img = min(img, p99_5);
    img = (img - meanVal) / stdVal;

    % Get bounding boxes
    props = regionprops3(foregroundMask, 'BoundingBox');
    bbox = ceil(props.BoundingBox(1,:));
    
    if sum(heartMask, 'all') > 0
        % Get bounding boxes
        foregroundProps = regionprops3(foregroundMask, 'BoundingBox');
        heartProps = regionprops3(heartMask, 'BoundingBox');
        
        foregroundBbox = ceil(foregroundProps.BoundingBox(1,:));
        heartBbox = ceil(heartProps.BoundingBox(1,:));
        
        % Crop XY to foreground region (with padding)
        padXY = 8;
        startX = max(1, foregroundBbox(1) - padXY);
        endX = min(size(img,2), foregroundBbox(1) + foregroundBbox(4) + padXY);
        startY = max(1, foregroundBbox(2) - padXY);
        endY = min(size(img,1), foregroundBbox(2) + foregroundBbox(5) + padXY);
        
        % Crop Z to heart region (with padding)
        padZ = 32;
        startZ = max(1, heartBbox(3) - padZ);
        endZ = min(size(img,3), heartBbox(3) + heartBbox(6) + padZ);
        
        % Apply cropping
        cropVol = img(startY:endY, startX:endX, startZ:endZ);
        cropLabel = combinedLabel(startY:endY, startX:endX, startZ:endZ);
        
        % Make size multiple of 8
        newSize = floor(size(cropVol)/8) * 8;
        cropVol = cropVol(1:newSize(1), 1:newSize(2), 1:newSize(3));
        cropLabel = cropLabel(1:newSize(1), 1:newSize(2), 1:newSize(3));

        % Normalize image
        cropVol = double(cropVol);

        % Compute statistics from cropped image
        meanVal = mean(cropVol, 'all');
        stdVal = std(cropVol, 0, 'all');
        p0_5 = prctile(cropVol, 0.5, 'all');
        p99_5 = prctile(cropVol, 99.5, 'all');
        
        % Apply normalization
        % 1. Clip to percentiles
        cropVol = max(cropVol, p0_5);
        cropVol = min(cropVol, p99_5);
        
        % 2. Subtract mean and divide by std
        cropVol = (cropVol - meanVal) ./ stdVal;
        
        % Split into train/val/test
        if id <= floor(0.7 * length(imgFiles))
            imgDir = fullfile(destination, 'imagesTr');
            lblDir = fullfile(destination, 'labelsTr');
        elseif id <= floor(0.9 * length(imgFiles))
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

        id=id+1;
    end
end