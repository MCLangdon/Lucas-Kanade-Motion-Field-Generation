% This is a sample file to overlay your quiver plot
% on the image for each image of every sequence
% Feel free to play around with this script.
% Resulting motion fields are overlayed on frames and saved in the current
% directory.

% Change folder_name to select images to use. Change LK_algorithm to either
% "LK_naive", "LK_iterative", or "LK_pyramid".
folder_name = 'Basketball';
LK_algorithm = "LK_pyramid";

% If necessary, change bounds of i here to select different frame numbers.
for i=7:13
    X = [' Frame numbers ',num2str(i),' and ',num2str(i+1)];
    disp(X)
    
    %reusing some part of the code given in demo_optical_flow.m
    [Vx, Vy] = demo_optical_flow(folder_name,i,i+1,LK_algorithm);
    
    s = size(Vx);
    step = max(s)/40;
    [X, Y] = meshgrid(1:step:s(2), s(1):-step:1);
    u = interp2(Vx, X, Y);
    v = interp2(Vy, X, Y);
 
    if(i < 10)
        
        Image_current = imread(fullfile(folder_name,strcat('frame0',num2str(i),'.png')));
    else
        Image_current = imread(fullfile(folder_name,strcat('frame',num2str(i),'.png')));
    end

    figure('visible','off');
    imagesc(unique(X),unique(Y),Image_current);
    hold all
    
    quiver(X, Y, u, v, 1, 'r', 'LineWidth', 1);
    axis image;
    
    FF=getframe;
    close;
    [Image,~]=frame2im(FF);

    imwrite(Image,strcat('flow',num2str(i),num2str(i+1),'.png'));

    close;
    
end
