classdef ImagePosterization_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        TabGroup                   matlab.ui.container.TabGroup
        LoadImageTab               matlab.ui.container.Tab
        HistorgramViewerPanel      matlab.ui.container.Panel
        GreenAxes                  matlab.ui.control.UIAxes
        RedAxes                    matlab.ui.control.UIAxes
        BlueAxes                   matlab.ui.control.UIAxes
        ImageViewerPanel           matlab.ui.container.Panel
        FilePathEditField          matlab.ui.control.EditField
        FilePathEditFieldLabel     matlab.ui.control.Label
        ImageAxes                  matlab.ui.control.UIAxes
        LoadImagePanel             matlab.ui.container.Panel
        LoadCustomImageButton      matlab.ui.control.Button
        PosterizationImageTab      matlab.ui.container.Tab
        Panel                      matlab.ui.container.Panel
        ImageAxes_2                matlab.ui.control.UIAxes
        EffectbuttomPanel          matlab.ui.container.Panel
        WriteImageButton           matlab.ui.control.Button
        AlphaSlider                matlab.ui.control.Slider
        AlphaSliderLabel           matlab.ui.control.Label
        MinButton                  matlab.ui.control.Button
        MaxButton                  matlab.ui.control.Button
        PosterizedHistorgramPanel  matlab.ui.container.Panel
        RedAxes_2                  matlab.ui.control.UIAxes
        BlueAxes_2                 matlab.ui.control.UIAxes
        GreenAxes_2                matlab.ui.control.UIAxes
        ImageAxes_3                matlab.ui.control.UIAxes
    end


    properties (Access = private)
        posterizedImage % Description
        originalImage % image
        outputImage
        pathName;
        fileName;
    end

    methods (Access = private)

        function upDateImage(app, filename)
            % For corn.tif, read the second image in the file
            if strcmp(filename,'corn.tif')
                im = imread('corn.tif', 2);
            else
                try
                    im = imread(filename);
                catch ME
                    % If problem reading image, display error message
                    uialert(app.UIFigure, ME.message, 'Image Error');
                    return;
                end
            end
            % Create histograms based on number of color channels
            switch size(im,3)
                case 1
                    % Display the grayscale image
                    imshow(uint8(im), 'Parent', app.ImageAxes);

                    % Plot all histograms with the same data for grayscale
                    histr = histogram(app.RedAxes, im, 'FaceColor',[1 0 0],'EdgeColor', 'none');
                    histg = histogram(app.GreenAxes, im, 'FaceColor',[0 1 0],'EdgeColor', 'none');
                    histb = histogram(app.BlueAxes, im, 'FaceColor',[0 0 1],'EdgeColor', 'none');

                case 3
                    % Display the truecolor image
                    imshow(uint8(im), 'Parent', app.ImageAxes);

                    % Plot the histograms
                    histr = histogram(app.RedAxes, im(:,:,1), 'FaceColor', [1 0 0], 'EdgeColor', 'none');
                    histg = histogram(app.GreenAxes, im(:,:,2), 'FaceColor', [0 1 0], 'EdgeColor', 'none');
                    histb = histogram(app.BlueAxes, im(:,:,3), 'FaceColor', [0 0 1], 'EdgeColor', 'none');

                otherwise
                    % Error when image is not grayscale or truecolor
                    uialert(app.UIFigure, 'Image must be grayscale or truecolor.', 'Image Error');
                    return;
            end

            % Compute posterized Image
            app.posterizedImage = Posterization(app, im);
            app.originalImage = im;
            % Get largest bin count
            maxr = max(histr.BinCounts);
            maxg = max(histg.BinCounts);
            maxb = max(histb.BinCounts);
            maxcount = max([maxr maxg maxb]);

            % Set y axes limits based on largest bin count
            app.RedAxes.YLim = [0 maxcount];
            app.RedAxes.YTick = round([0 maxcount/2 maxcount], 2, 'significant');
            app.GreenAxes.YLim = [0 maxcount];
            app.GreenAxes.YTick = round([0 maxcount/2 maxcount], 2, 'significant');
            app.BlueAxes.YLim = [0 maxcount];
            app.BlueAxes.YTick = round([0 maxcount/2 maxcount], 2, 'significant');
            app.ImageAxes.XLim = [0, size(im, 2) + 1];
            app.ImageAxes.YLim = [0, size(im, 1) + 1];
        end

        function vBR = brightMembership(~, p)
            a_br = 177;
            b_br = 50;
            if a_br - b_br <= p && p <=  a_br
                vBR = 1 - (a_br - p)/ b_br;
            elseif a_br < p
                vBR = 1;
            else
                vBR = 0;
            end
        end

        function vG = grayMembership(~, p)
            a_g = 127;
            b_g = 50;
            if a_g - b_g <= p && p <=  a_g
                vG = 1 - (a_g - p) / b_g;
            elseif a_g < p && p <= a_g + b_g
                vG = 1 - (p - a_g) / b_g;
            else
                vG = 0;
            end
        end

        function vDR = darkMembership(~, p)
            a_dr = 73;
            b_dr = 50;
            if a_dr <= p && p <=  a_dr + b_dr
                vDR = 1 - (p - a_dr) / b_dr;
            elseif p < a_dr
                vDR = 1;
            else
                vDR = 0;
            end
        end

        function F = Fuzzy(app, I)
            F = zeros(size(I));
            [rows, cols]= size(I);
            vd = 0;
            vg = 127;
            vb = 255;
            for j = 1: rows
                for i = 1:cols
                    vDR=darkMembership(app, I(j, i));
                    vG=grayMembership(app, I(j, i));
                    vBR=brightMembership(app, I(j, i));
                    v = (vDR * vd + vG * vg + vBR * vb) / (vDR + vG + vBR);
                    [~,index] = min([abs(v - vd), abs(v - vg), abs(v - vb)]);
                    if index == 1
                        F(j, i) = vd;
                    elseif index == 2
                        F(j, i) = vg;
                    else
                        F(j, i) = vb;
                    end
                end
            end
        end
        function F = Posterization(app, I)
            degreeOfSmoothing = 7.5;
            spatialSigma = 15;
            I = imbilatfilt(I, degreeOfSmoothing, spatialSigma);
            if ndims(I) == 3
                F = zeros(size(I));
                for i = 1:size(I,3)
                    F(:, :, i) = Fuzzy(app, I(:, :, i));
                end
            else
                F = Fuzzy(app, I);
            end
            F = uint8(F);
        end

        function upDateHist(app,im)
            switch size(im,3)
                case 1
                    % Display the grayscale image
                    imshow(uint8(im), 'Parent', app.ImageAxes);

                    % Plot all histograms with the same data for grayscale
                    histr = histogram(app.RedAxes_2, im, 'FaceColor',[1 0 0],'EdgeColor', 'none');
                    histg = histogram(app.GreenAxes_2, im, 'FaceColor',[0 1 0],'EdgeColor', 'none');
                    histb = histogram(app.BlueAxes_2, im, 'FaceColor',[0 0 1],'EdgeColor', 'none');

                case 3
                    % Display the truecolor image
                    imshow(uint8(im), 'Parent', app.ImageAxes);

                    % Plot the histograms
                    histr = histogram(app.RedAxes_2, im(:,:,1), 'FaceColor', [1 0 0], 'EdgeColor', 'none');
                    histg = histogram(app.GreenAxes_2, im(:,:,2), 'FaceColor', [0 1 0], 'EdgeColor', 'none');
                    histb = histogram(app.BlueAxes_2, im(:,:,3), 'FaceColor', [0 0 1], 'EdgeColor', 'none');

                otherwise
                    % Error when image is not grayscale or truecolor
                    uialert(app.UIFigure, 'Image must be grayscale or truecolor.', 'Image Error');
                    return;
            end
            % Get largest bin count
            maxr = max(histr.BinCounts);
            maxg = max(histg.BinCounts);
            maxb = max(histb.BinCounts);
            maxcount = max([maxr maxg maxb]);

            % Set y axes limits based on largest bin count
            app.RedAxes_2.YLim = [0 maxcount];
            app.RedAxes_2.YTick = round([0 maxcount/2 maxcount], 2, 'significant');
            app.GreenAxes_2.YLim = [0 maxcount];
            app.GreenAxes_2.YTick = round([0 maxcount/2 maxcount], 2, 'significant');
            app.BlueAxes_2.YLim = [0 maxcount];
            app.BlueAxes_2.YTick = round([0 maxcount/2 maxcount], 2, 'significant');
            app.ImageAxes_2.XLim = [0, size(im, 2) + 1];
            app.ImageAxes_2.YLim = [0, size(im, 1) + 1];
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: LoadCustomImageButton
        function LoadCustomImageButtonPushed(app, event)
            filterspec = {'*.jpg;*.tif;*.png;*.gif','All Image Files'};
            [app.fileName, app.pathName] = uigetfile(filterspec);
            if app.fileName == 0
                msgbox('Invalid File', 'Error','error');
                return;
            else
                if (ischar(app.pathName))
                    absolutePath = [app.pathName, app.fileName];
                    app.FilePathEditField.Value = absolutePath;
                    upDateImage(app, absolutePath);
                else
                    msgbox('Invalid File', 'Error','error');
                    return;
                end
            end
            % Make sure user didn't cancel uigetfile dialog

        end

        % Button pushed function: MaxButton
        function MaxButtonPushed(app, event)
            I = app.originalImage;
            P = app.posterizedImage;
            app.outputImage = max(I, P);
            imshow(uint8(app.outputImage),'Parent', app.ImageAxes_2);
            upDateHist(app, uint8(app.outputImage));

        end

        % Button pushed function: MinButton
        function MinButtonPushed(app, event)
            I = app.originalImage;
            P = app.posterizedImage;
            app.outputImage = min(I, P);
            imshow(uint8(app.outputImage),'Parent', app.ImageAxes_2);
            upDateHist(app, uint8(app.outputImage));
        end

        % Value changing function: AlphaSlider
        function AlphaSliderValueChanging(app, event)
            changingValue = event.Value;
            I = app.originalImage;
            P = app.posterizedImage;
            app.outputImage = changingValue * P + (1 - changingValue) * I;
            imshow(uint8(app.outputImage),'Parent', app.ImageAxes_2);
            upDateHist(app, uint8(app.outputImage));
        end

        % Button pushed function: WriteImageButton
        function WriteImageButtonPushed(app, event)

            imwrite(app.outputImage, [app.pathName, erase(app.fileName,'.jpg'),...
                '_posterized_img.jpg']);
            myicon = app.originalImage;
            msgbox('Operation Completed','Success','custom',myicon);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 733 520];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Resize = 'off';

            % Create ImageAxes_3
            app.ImageAxes_3 = uiaxes(app.UIFigure);
            app.ImageAxes_3.XTick = [];
            app.ImageAxes_3.XTickLabel = {'[ ]'};
            app.ImageAxes_3.YTick = [];
            app.ImageAxes_3.Position = [43 181 357 305];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.Position = [2 5 728 516];

            % Create LoadImageTab
            app.LoadImageTab = uitab(app.TabGroup);
            app.LoadImageTab.AutoResizeChildren = 'off';
            app.LoadImageTab.Title = 'Load Image';

            % Create LoadImagePanel
            app.LoadImagePanel = uipanel(app.LoadImageTab);
            app.LoadImagePanel.AutoResizeChildren = 'off';
            app.LoadImagePanel.Title = 'Load Image';
            app.LoadImagePanel.Position = [2 0 425 139];

            % Create LoadCustomImageButton
            app.LoadCustomImageButton = uibutton(app.LoadImagePanel, 'push');
            app.LoadCustomImageButton.ButtonPushedFcn = createCallbackFcn(app, @LoadCustomImageButtonPushed, true);
            app.LoadCustomImageButton.Position = [150 58 124 22];
            app.LoadCustomImageButton.Text = 'Load Custom Image';

            % Create ImageViewerPanel
            app.ImageViewerPanel = uipanel(app.LoadImageTab);
            app.ImageViewerPanel.AutoResizeChildren = 'off';
            app.ImageViewerPanel.Title = 'Image Viewer';
            app.ImageViewerPanel.Position = [0 138 426 354];

            % Create ImageAxes
            app.ImageAxes = uiaxes(app.ImageViewerPanel);
            app.ImageAxes.XTick = [];
            app.ImageAxes.XTickLabel = {'[ ]'};
            app.ImageAxes.YTick = [];
            app.ImageAxes.Position = [13 38 397 294];

            % Create FilePathEditFieldLabel
            app.FilePathEditFieldLabel = uilabel(app.ImageViewerPanel);
            app.FilePathEditFieldLabel.HorizontalAlignment = 'right';
            app.FilePathEditFieldLabel.Position = [37 11 53 22];
            app.FilePathEditFieldLabel.Text = 'File Path';

            % Create FilePathEditField
            app.FilePathEditField = uieditfield(app.ImageViewerPanel, 'text');
            app.FilePathEditField.Position = [99 11 290 22];

            % Create HistorgramViewerPanel
            app.HistorgramViewerPanel = uipanel(app.LoadImageTab);
            app.HistorgramViewerPanel.AutoResizeChildren = 'off';
            app.HistorgramViewerPanel.Title = 'Historgram Viewer';
            app.HistorgramViewerPanel.Position = [426 1 301 491];

            % Create BlueAxes
            app.BlueAxes = uiaxes(app.HistorgramViewerPanel);
            title(app.BlueAxes, 'Blue')
            xlabel(app.BlueAxes, 'Intensity')
            ylabel(app.BlueAxes, 'Pixels')
            app.BlueAxes.XLim = [0 255];
            app.BlueAxes.XTick = [0 128 255];
            app.BlueAxes.Position = [33 17 236 152];

            % Create RedAxes
            app.RedAxes = uiaxes(app.HistorgramViewerPanel);
            title(app.RedAxes, 'Red')
            xlabel(app.RedAxes, 'Intensity')
            ylabel(app.RedAxes, 'Pixels')
            app.RedAxes.XLim = [0 255];
            app.RedAxes.XTick = [0 128 255];
            app.RedAxes.Position = [33 319 236 152];

            % Create GreenAxes
            app.GreenAxes = uiaxes(app.HistorgramViewerPanel);
            title(app.GreenAxes, 'Green')
            xlabel(app.GreenAxes, 'Intensity')
            ylabel(app.GreenAxes, 'Pixels')
            app.GreenAxes.XLim = [0 255];
            app.GreenAxes.XTick = [0 128 255];
            app.GreenAxes.Position = [33 168 236 152];

            % Create PosterizationImageTab
            app.PosterizationImageTab = uitab(app.TabGroup);
            app.PosterizationImageTab.AutoResizeChildren = 'off';
            app.PosterizationImageTab.Title = 'Posterization Image';

            % Create PosterizedHistorgramPanel
            app.PosterizedHistorgramPanel = uipanel(app.PosterizationImageTab);
            app.PosterizedHistorgramPanel.AutoResizeChildren = 'off';
            app.PosterizedHistorgramPanel.Title = 'Posterized Historgram';
            app.PosterizedHistorgramPanel.Position = [426 1 301 491];

            % Create GreenAxes_2
            app.GreenAxes_2 = uiaxes(app.PosterizedHistorgramPanel);
            title(app.GreenAxes_2, 'Green')
            xlabel(app.GreenAxes_2, 'Intensity')
            ylabel(app.GreenAxes_2, 'Pixels')
            app.GreenAxes_2.XLim = [0 255];
            app.GreenAxes_2.XTick = [0 128 255];
            app.GreenAxes_2.Position = [35 168 236 152];

            % Create BlueAxes_2
            app.BlueAxes_2 = uiaxes(app.PosterizedHistorgramPanel);
            title(app.BlueAxes_2, 'Blue')
            xlabel(app.BlueAxes_2, 'Intensity')
            ylabel(app.BlueAxes_2, 'Pixels')
            app.BlueAxes_2.XLim = [0 255];
            app.BlueAxes_2.XTick = [0 128 255];
            app.BlueAxes_2.Position = [34 1 236 152];

            % Create RedAxes_2
            app.RedAxes_2 = uiaxes(app.PosterizedHistorgramPanel);
            title(app.RedAxes_2, 'Red')
            xlabel(app.RedAxes_2, 'Intensity')
            ylabel(app.RedAxes_2, 'Pixels')
            app.RedAxes_2.XLim = [0 255];
            app.RedAxes_2.XTick = [0 128 255];
            app.RedAxes_2.Position = [33 319 236 152];

            % Create EffectbuttomPanel
            app.EffectbuttomPanel = uipanel(app.PosterizationImageTab);
            app.EffectbuttomPanel.AutoResizeChildren = 'off';
            app.EffectbuttomPanel.Title = 'Effect buttom';
            app.EffectbuttomPanel.Position = [2 375 424 117];

            % Create MaxButton
            app.MaxButton = uibutton(app.EffectbuttomPanel, 'push');
            app.MaxButton.ButtonPushedFcn = createCallbackFcn(app, @MaxButtonPushed, true);
            app.MaxButton.Position = [286 68 100 22];
            app.MaxButton.Text = 'Max';

            % Create MinButton
            app.MinButton = uibutton(app.EffectbuttomPanel, 'push');
            app.MinButton.ButtonPushedFcn = createCallbackFcn(app, @MinButtonPushed, true);
            app.MinButton.Position = [286 37 100 22];
            app.MinButton.Text = 'Min';

            % Create AlphaSliderLabel
            app.AlphaSliderLabel = uilabel(app.EffectbuttomPanel);
            app.AlphaSliderLabel.HorizontalAlignment = 'right';
            app.AlphaSliderLabel.Position = [11 47 36 22];
            app.AlphaSliderLabel.Text = 'Alpha';

            % Create AlphaSlider
            app.AlphaSlider = uislider(app.EffectbuttomPanel);
            app.AlphaSlider.Limits = [0 1];
            app.AlphaSlider.ValueChangingFcn = createCallbackFcn(app, @AlphaSliderValueChanging, true);
            app.AlphaSlider.Position = [58 58 185 3];

            % Create WriteImageButton
            app.WriteImageButton = uibutton(app.EffectbuttomPanel, 'push');
            app.WriteImageButton.ButtonPushedFcn = createCallbackFcn(app, @WriteImageButtonPushed, true);
            app.WriteImageButton.Position = [286 7 100 22];
            app.WriteImageButton.Text = 'Write Image';

            % Create Panel
            app.Panel = uipanel(app.PosterizationImageTab);
            app.Panel.AutoResizeChildren = 'off';
            app.Panel.Title = 'Panel';
            app.Panel.Position = [1 2 424 374];

            % Create ImageAxes_2
            app.ImageAxes_2 = uiaxes(app.Panel);
            app.ImageAxes_2.XTick = [];
            app.ImageAxes_2.XTickLabel = {'[ ]'};
            app.ImageAxes_2.YTick = [];
            app.ImageAxes_2.Position = [12 16 400 326];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ImagePosterization_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end