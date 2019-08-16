classdef LeWoS_RS < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        LeWoSUIFigure                   matlab.ui.Figure
        RunSegmentationButton           matlab.ui.control.Button
        UIAxes                          matlab.ui.control.UIAxes
        ShowButton                      matlab.ui.control.Button
        LoadPointCloudButton            matlab.ui.control.Button
        ParallelComputingnThreadsLabel  matlab.ui.control.Label
        ParallelComputingnThreadsEditField  matlab.ui.control.NumericEditField
        S1Lamp                          matlab.ui.control.Lamp
        ShowButton_2                    matlab.ui.control.Button
        ThresholdLabel                  matlab.ui.control.Label
        ThresholdEditField              matlab.ui.control.NumericEditField
        S2Lamp                          matlab.ui.control.Lamp
        S3Lamp                          matlab.ui.control.Lamp
        ExportResultsButton             matlab.ui.control.Button
        ResetProgramButton              matlab.ui.control.Button
        LeafWoodSeparationLeWoSfromPointCloudDataLabel  matlab.ui.control.Label
        ProgressMonitorLabel            matlab.ui.control.Label
    end

    
    properties (Access = private)
        
        points = 0;
        BiLabel_Regu = 0;
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: RunSegmentationButton
        function RunSegmentationButtonPushed(app, event)
            
            app.ProgressMonitorLabel.Text = 'Running progressive segmentation...';
            app.S2Lamp.Color = 'yellow';
            pause(.1)
            
            p = gcp('nocreate'); % If no pool, create new one.
            if isempty(p)
                parpool('local',app.ParallelComputingnThreadsEditField.Value);
            end
            
            [~, app.BiLabel_Regu] = RecursiveSegmentation_release(app.points,app.ThresholdEditField.Value,1,0);
            
            app.S2Lamp.Color = 'green';
            app.ProgressMonitorLabel.Text = 'Running progressive segmentation done !!';
            
        end

        % Button pushed function: ShowButton
        function ShowButtonPushed(app, event)
            app.ProgressMonitorLabel.Text = 'Plotting results...';
            pause(.1)
                        % downsample to increase performance
            if size(app.points,1)>500000
                p = randperm(size(app.points,1),50000);
            else
                p = 1:size(app.points,1);
            end
            pts = app.points(p,:);
            lb = app.BiLabel_Regu(p);
            
            wood = pts(lb==1,:);
            leaf = pts(lb~=1,:);
            plot3(app.UIAxes,wood(:,1),wood(:,2),wood(:,3),'.','color',[0.4471, 0.3216, 0.1647],'MarkerSize',1);
            hold(app.UIAxes,"on")
            plot3(app.UIAxes,leaf(:,1),leaf(:,2),leaf(:,3),'.','color',[0.2667, 0.5686, 0.1961],'MarkerSize',1);
            hold(app.UIAxes,"off")
            axis(app.UIAxes, 'equal');
            axis(app.UIAxes, 'off');
            title(app.UIAxes,' ');
            app.ProgressMonitorLabel.Text = 'Plotting results done!!';
        end

        % Button pushed function: LoadPointCloudButton
        function LoadPointCloudButtonPushed(app, event)
            app.ProgressMonitorLabel.Text = 'Loading point cloud...';
            app.S1Lamp.Color = 'yellow';
            pause(.1)
            [filename, pathname] = uigetfile({'*.las;*.laz;*.mat;*.xyz;*.txt;*.ply;*.pcd',...
                'Point Cloud Files (*.las,*.laz;*.mat,*.xyz,*.txt,*.ply,*.pcd)';...
                '*.*',  'All Files (*.*)'}, ...
                'Select a File');
            if isequal(filename,0)
                app.ProgressMonitorLabel.Text = 'User selected Cancel';
                return
            end
            Filepath = strcat(pathname,filename);
            [~,~,fExt] = fileparts(Filepath);
            
            app.points = []; %init
            switch lower(fExt)
                case '.las'
                    pt = lasdata(Filepath);
                    app.points = [pt.x,pt.y,pt.z];
                case '.laz'
                    pt = lasdata(Filepath);
                    app.points = [pt.x,pt.y,pt.z];
                case '.txt'
                    formatSpec = '%25f%25f%25f%*[^\n]';
                    fileID = fopen(Filepath,'r');
                    dataArray = textscan(fileID, formatSpec, 'Delimiter', '', 'WhiteSpace', '', 'EmptyValue' ,NaN, 'ReturnOnError', false);
                    fclose(fileID);
                    app.points = cell2mat(dataArray);
                case '.xyz'
                    formatSpec = '%25f%25f%25f%*[^\n]';
                    fileID = fopen(Filepath,'r');
                    dataArray = textscan(fileID, formatSpec, 'Delimiter', '', 'WhiteSpace', '', 'EmptyValue' ,NaN, 'ReturnOnError', false);
                    fclose(fileID);
                    app.points = cell2mat(dataArray);
                case '.ply'
                    ptCloud = pcread(Filepath);
                    app.points = ptCloud.Location;
                case '.pcd'
                    ptCloud = pcread(Filepath);
                    app.points = ptCloud.Location;
                case '.mat'
                    a = load(Filepath);
                    c = cell2mat(struct2cell(a));
                    app.points = c(:,1:3);
                otherwise  % Under all circumstances SWITCH gets an OTHERWISE!
                    error('Unexpected file extension: %s', fExt);
            end
            
            app.points = double(unique(app.points,'rows'));% ensure double
            
            %% auto estimate number of workers available
            c = parcluster('local');
            nw = c.NumWorkers;
            if nw <= app.ParallelComputingnThreadsEditField.Value
                app.ParallelComputingnThreadsEditField.Value = nw;
            end
            %
            app.S1Lamp.Color = 'green';
            app.ProgressMonitorLabel.Text = 'Loading point cloud done !!';
        end

        % Button pushed function: ShowButton_2
        function ShowButton_2Pushed(app, event)
            app.ProgressMonitorLabel.Text = 'Plotting point cloud...';
            pause(.1)
            % downsample to increase performance
            if size(app.points,1)>500000
                p = randperm(size(app.points,1),50000);
            else
                p = 1:size(app.points,1);
            end
            scatter3(app.UIAxes,app.points(p,1),app.points(p,2),app.points(p,3),1,app.points(p,3),"filled");
            colormap(app.UIAxes,"jet")
            axis(app.UIAxes,'off')
            axis(app.UIAxes,'equal')
            t = max(app.points) - min(app.points);
            title(app.UIAxes, {['Number of points ',num2str(size(app.points,1))], ['Dimension ' num2str(round(t(1),2)) ' x ' num2str(round(t(2),2)) ' x ' num2str(round(t(3),2))]})
            app.ProgressMonitorLabel.Text = 'Plotting point cloud done !!';
        end

        % Button pushed function: ExportResultsButton
        function ExportResultsButtonPushed(app, event)
            [filename, pathname] = uiputfile('leaf_wood_results.txt','Save file name');
            if isequal(filename,0)
                app.ProgressMonitorLabel.Text = 'User selected Cancel';
                return
            else
                %disp(['User selected ', fullfile(pathname, filename)])
            end
            Filepath = strcat(pathname,filename);
            
            app.ProgressMonitorLabel.Text = 'Saving wood-leaf separation results...';
            app.S3Lamp.Color = 'yellow';
            pause(.1)
            wood = app.points(app.BiLabel_Regu==1,:);
            leaf = app.points(app.BiLabel_Regu~=1,:);
            
            a = [[wood,ones(size(wood,1),1)];[leaf,zeros(size(leaf,1),1)]];
            
            % write as txt
            file = fopen(Filepath, 'w');
            fprintf(file, '%.6f %.6f %.6f %d\n', a');
            fclose(file);
            
            app.S3Lamp.Color = 'green';
            app.ProgressMonitorLabel.Text = 'Saving leaf-wood separation results done !!';
        end

        % Button pushed function: ResetProgramButton
        function ResetProgramButtonPushed(app, event)
            app.S1Lamp.Color = [0 0.451 0.7412];
            app.S2Lamp.Color = [0 0.451 0.7412];
            app.S3Lamp.Color = [0 0.451 0.7412];
            
            app.points = 0;
            app.BiLabel_Regu = 0;
            cla(app.UIAxes)
            title(app.UIAxes,' ');
            close all
            clc
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create LeWoSUIFigure and hide until all components are created
            app.LeWoSUIFigure = uifigure('Visible', 'off');
            app.LeWoSUIFigure.Color = [0.9412 0.9412 0.9412];
            app.LeWoSUIFigure.Position = [100 100 1044 791];
            app.LeWoSUIFigure.Name = 'LeWoS';

            % Create RunSegmentationButton
            app.RunSegmentationButton = uibutton(app.LeWoSUIFigure, 'push');
            app.RunSegmentationButton.ButtonPushedFcn = createCallbackFcn(app, @RunSegmentationButtonPushed, true);
            app.RunSegmentationButton.FontName = 'Yu Gothic UI';
            app.RunSegmentationButton.Position = [719 465 136 25];
            app.RunSegmentationButton.Text = 'Run Segmentation';

            % Create UIAxes
            app.UIAxes = uiaxes(app.LeWoSUIFigure);
            title(app.UIAxes, '')
            xlabel(app.UIAxes, '')
            ylabel(app.UIAxes, '')
            app.UIAxes.FontName = 'Yu Gothic UI';
            app.UIAxes.Box = 'on';
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            app.UIAxes.Clipping = 'off';
            app.UIAxes.Position = [1 1 617 691];

            % Create ShowButton
            app.ShowButton = uibutton(app.LeWoSUIFigure, 'push');
            app.ShowButton.ButtonPushedFcn = createCallbackFcn(app, @ShowButtonPushed, true);
            app.ShowButton.FontName = 'Yu Gothic UI';
            app.ShowButton.Position = [904 464 100 25];
            app.ShowButton.Text = 'Show';

            % Create LoadPointCloudButton
            app.LoadPointCloudButton = uibutton(app.LeWoSUIFigure, 'push');
            app.LoadPointCloudButton.ButtonPushedFcn = createCallbackFcn(app, @LoadPointCloudButtonPushed, true);
            app.LoadPointCloudButton.FontName = 'Yu Gothic UI';
            app.LoadPointCloudButton.Position = [719 576 136 25];
            app.LoadPointCloudButton.Text = 'Load Point Cloud';

            % Create ParallelComputingnThreadsLabel
            app.ParallelComputingnThreadsLabel = uilabel(app.LeWoSUIFigure);
            app.ParallelComputingnThreadsLabel.HorizontalAlignment = 'right';
            app.ParallelComputingnThreadsLabel.FontName = 'Yu Gothic UI';
            app.ParallelComputingnThreadsLabel.Position = [686 613 109 32];
            app.ParallelComputingnThreadsLabel.Text = {'Parallel Computing '; 'nThreads'};

            % Create ParallelComputingnThreadsEditField
            app.ParallelComputingnThreadsEditField = uieditfield(app.LeWoSUIFigure, 'numeric');
            app.ParallelComputingnThreadsEditField.Limits = [2 10000];
            app.ParallelComputingnThreadsEditField.HorizontalAlignment = 'center';
            app.ParallelComputingnThreadsEditField.FontName = 'Yu Gothic UI';
            app.ParallelComputingnThreadsEditField.Position = [810 618 45 22];
            app.ParallelComputingnThreadsEditField.Value = 10;

            % Create S1Lamp
            app.S1Lamp = uilamp(app.LeWoSUIFigure);
            app.S1Lamp.Position = [669 580 20 20];
            app.S1Lamp.Color = [0 0.4471 0.7412];

            % Create ShowButton_2
            app.ShowButton_2 = uibutton(app.LeWoSUIFigure, 'push');
            app.ShowButton_2.ButtonPushedFcn = createCallbackFcn(app, @ShowButton_2Pushed, true);
            app.ShowButton_2.FontName = 'Yu Gothic UI';
            app.ShowButton_2.Position = [904 576 100 25];
            app.ShowButton_2.Text = 'Show';

            % Create ThresholdLabel
            app.ThresholdLabel = uilabel(app.LeWoSUIFigure);
            app.ThresholdLabel.HorizontalAlignment = 'right';
            app.ThresholdLabel.FontName = 'Yu Gothic UI';
            app.ThresholdLabel.Position = [719 504 76 22];
            app.ThresholdLabel.Text = 'Threshold';

            % Create ThresholdEditField
            app.ThresholdEditField = uieditfield(app.LeWoSUIFigure, 'numeric');
            app.ThresholdEditField.Limits = [0.0001 1];
            app.ThresholdEditField.HorizontalAlignment = 'center';
            app.ThresholdEditField.FontName = 'Yu Gothic UI';
            app.ThresholdEditField.Position = [810 504 45 22];
            app.ThresholdEditField.Value = 0.125;

            % Create S2Lamp
            app.S2Lamp = uilamp(app.LeWoSUIFigure);
            app.S2Lamp.Position = [669 468 20 20];
            app.S2Lamp.Color = [0 0.4471 0.7412];

            % Create S3Lamp
            app.S3Lamp = uilamp(app.LeWoSUIFigure);
            app.S3Lamp.Position = [669 366 20 20];
            app.S3Lamp.Color = [0 0.4471 0.7412];

            % Create ExportResultsButton
            app.ExportResultsButton = uibutton(app.LeWoSUIFigure, 'push');
            app.ExportResultsButton.ButtonPushedFcn = createCallbackFcn(app, @ExportResultsButtonPushed, true);
            app.ExportResultsButton.FontName = 'Yu Gothic UI';
            app.ExportResultsButton.Position = [719 362 136 25];
            app.ExportResultsButton.Text = 'Export Results';

            % Create ResetProgramButton
            app.ResetProgramButton = uibutton(app.LeWoSUIFigure, 'push');
            app.ResetProgramButton.ButtonPushedFcn = createCallbackFcn(app, @ResetProgramButtonPushed, true);
            app.ResetProgramButton.FontName = 'Yu Gothic UI';
            app.ResetProgramButton.Position = [719 244 136 25];
            app.ResetProgramButton.Text = 'Reset Program';

            % Create LeafWoodSeparationLeWoSfromPointCloudDataLabel
            app.LeafWoodSeparationLeWoSfromPointCloudDataLabel = uilabel(app.LeWoSUIFigure);
            app.LeafWoodSeparationLeWoSfromPointCloudDataLabel.BackgroundColor = [0.8 0.8 0.8];
            app.LeafWoodSeparationLeWoSfromPointCloudDataLabel.HorizontalAlignment = 'center';
            app.LeafWoodSeparationLeWoSfromPointCloudDataLabel.FontName = 'Yu Gothic UI';
            app.LeafWoodSeparationLeWoSfromPointCloudDataLabel.FontSize = 20;
            app.LeafWoodSeparationLeWoSfromPointCloudDataLabel.Position = [1 713 1044 79];
            app.LeafWoodSeparationLeWoSfromPointCloudDataLabel.Text = 'Leaf-Wood Separation (LeWoS) from Point Cloud Data';

            % Create ProgressMonitorLabel
            app.ProgressMonitorLabel = uilabel(app.LeWoSUIFigure);
            app.ProgressMonitorLabel.VerticalAlignment = 'top';
            app.ProgressMonitorLabel.FontName = 'Yu Gothic UI';
            app.ProgressMonitorLabel.FontSize = 14;
            app.ProgressMonitorLabel.FontColor = [0.9882 0 0.298];
            app.ProgressMonitorLabel.Position = [719 85 285 100];
            app.ProgressMonitorLabel.Text = 'Progress Monitor:';

            % Show the figure after all components are created
            app.LeWoSUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = LeWoS_RS

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.LeWoSUIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.LeWoSUIFigure)
        end
    end
end

