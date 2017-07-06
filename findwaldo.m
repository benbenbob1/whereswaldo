function [] = findwaldo(filename, actual)
    tic;
    try
        I = imread(filename);
    catch
        fprintf('Could not find file ''%s''\n', filename);
        return;
    end
    markup = I;
    Ithresh = zeros(size(I,1), size(I,2), 'uint8');
    rgbThresh = [120, 255; 25, 97; 17, 110];
    pupilThreshMin = [0, 100];
    pupilThreshMax = [190, 255];
    hatSizeRatio = [1.2, 2.7];
    hatOrientationThresh = [-50, 24];
    for x=1:size(Ithresh,1)
        for y=1:size(Ithresh,2)
            for c=1:size(I,3)
                val = I(x,y,c);
                if (val >= rgbThresh(c,1) && val <= rgbThresh(c,2))
                    Ithresh(x,y) = Ithresh(x,y) + 1;
                end
            end
        end
    end
    
    Ibw = (Ithresh(:,:) == 3);
    close = imclose(...
        imopen(Ibw(:,:), strel('square', 2)),...
        strel('square', 12)...
    );
    %width = size(Ibw, 1);
    %closeA = bwareafilt(close, [0.020 * width, 0.08 * width]);
    closeA = bwareafilt(close, [30, 120]);
    conn = bwconncomp(closeA);
    data = regionprops(conn,...
        'Centroid',...
        'MajorAxisLength',...
        'MinorAxisLength',...
        'Orientation'...
    );

    recognized = [];
    
    %--
    elimSCount = 0;
    elimOCount = 0;
    %--
    
    for i=1:conn.NumObjects
        blob = data(i);
        blobCenter = blob.Centroid;
        blobSize = [blob.MajorAxisLength, blob.MinorAxisLength];
        blobOrn = blob.Orientation;
        sizeRatio = blobSize(1)/blobSize(2);
        
        % eliminate based on ratio of width/height
        if (sizeRatio < hatSizeRatio(1) || ...
            sizeRatio > hatSizeRatio(2))
            %--
            elimSCount = elimSCount + 1;
            %--
            continue
        end
        
        % eliminate based on orientation
        if (blobOrn >= 89)
            blobOrn = blobOrn - 90;
        end
        if (blobOrn < hatOrientationThresh(1) || ...
            blobOrn > hatOrientationThresh(2))
            %--
            elimOCount = elimOCount + 1;
            %--
            continue
        end
        
        
        %[x y width height]
        possibleWaldoBox = [
            blobCenter(1)-(blobSize(1)/2.0)+5.0,...
            blobCenter(2)-(blobSize(2)/2.0)+5.0,...
            blobSize(1) + 8.0,...
            blobSize(2) + 8.0
        ];
        try
            possiblyWaldo = imresize(imcrop(I, possibleWaldoBox), 10);
        catch
            % catch when possibleWaldoBox doesnt intersect I
            continue
        end
        binaryWaldo = imtophat(imclose(imbinarize(rgb2gray(possiblyWaldo), 0.55), strel('disk', 5)), strel('disk', 19));
        %binaryWaldo = imbothat(imbinarize(rgb2gray(possiblyWaldo), 0.5), strel('disk', 10));
        %binaryWaldo = imtophat(imdilate(imerode(imbinarize(rgb2gray(possiblyWaldo), 0.6), strel('disk', 6)), strel('disk', 8)), strel('disk', 12));
        [wC, wR, wM] = imfindcircles(binaryWaldo, [18 35], 'ObjectPolarity', 'bright');
        if (size(wC,1) == 0)
            continue
        end

        numCircles = min(5, size(wC,1));

        try
            if (size(actual, 2) == 2)
                if (abs(possibleWaldoBox(1) - actual(1)) <= 20 && abs(possibleWaldoBox(2) - actual(2)) <= 20)
                    fprintf('Found my waldo (%i)\n', i);
                    fprintf('Ratio: %0.3f, Orientation: %.2f\n', sizeRatio, blobOrn);
                end
            end
        catch
        end
        
        foundEye = 0;
        for c=1:numCircles
            if (wM(c) < 0.15)
                continue;
            end
            
            eyeBoxS = sqrt(2.0*wR(c)^2.0);
            %x y width height
            eyeBox = [
                uint8(wC(c,1) - eyeBoxS/2.0) + 3,...
                uint8(wC(c,2) - eyeBoxS/2.0) + 3,...
                uint8(eyeBoxS) - 6,...
                uint8(eyeBoxS) - 6
            ];
            pWaldoGray = rgb2gray(possiblyWaldo);
            try
                eyeCrop = pWaldoGray(eyeBox(2):eyeBox(2)+eyeBox(4), eyeBox(1):eyeBox(1)+eyeBox(3));
                pupilMin = min(min(eyeCrop));
                pupilMax = max(max(eyeCrop));

                if (pupilMin >= pupilThreshMin(1) && pupilMin <= pupilThreshMin(2) &&...
                    pupilMax >= pupilThreshMax(1) && pupilMax <= pupilThreshMax(2))
                    foundEye = 1;
                    break;
                end
            catch
                foundEye = 0;
            end

        end

        if (foundEye == 1)
            waldoBox = [
                possibleWaldoBox(1) - 10.0,...
                possibleWaldoBox(2) - 8.0,...
                possibleWaldoBox(3) + 14.0,...
                possibleWaldoBox(4) + 80.0
            ];
            markup = insertShape(markup, 'Rectangle', waldoBox, 'LineWidth', 5, 'Color', 'green');
            recognized(size(recognized,1)+1,:) = waldoBox;
        else
            markup = insertShape(markup, 'Rectangle', possibleWaldoBox, 'LineWidth', 5, 'Color', 'red');
        end
        %viscircles(possibleWaldoBox(1:2)+wC(1:3,:), r(1:3));
    end

    for w=1:size(recognized,1)
        rec = recognized(w, :);
        subplot(1,size(recognized,1),w), imshow(imcrop(I, rec));
        fprintf('Found waldo %i at (%d, %d)\n', w, rec(1), rec(2));
    end
    figure, imshow(markup);
    t = toc;
    fprintf('WW completed in %f seconds.\n\n', t);
    fprintf('Eliminated %i out of %i CCs due to ratio\n', elimSCount, conn.NumObjects);
    fprintf('Eliminated %i out of %i CCs due to angle\n', elimOCount, conn.NumObjects-elimSCount);
    fprintf('----------------------------------------\n');
    fprintf(' = %i Total eliminated\n', elimSCount+elimOCount);