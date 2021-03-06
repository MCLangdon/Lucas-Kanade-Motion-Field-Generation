function [Vx,Vy] = compute_LK_optical_flow(frame_1,frame_2,type_LK)

% Implementation of the Lucas Kanade algorithm to compute the
% frame to frame motion field estimates. 
% frame_1 and frame_2 are two gray frames given as inputs to 
% this function. (Vx,Vy) is the motion field computed using these frames.

% There are three variations of LK implemented,
% select the desired algorithm by passing in the argument as follows:
% "LK_naive", "LK_iterative" or "LK_pyramid". "LK_pyramid" provides the
% most refined motion field.

frame_1 = frame_1(:,:,2);
frame_2 = frame_2(:,:,2);

[M,N] = size(frame_1);
Vx = zeros(M, N);
Vy = zeros(M, N);

switch type_LK

    case "LK_naive"
        % Gaussian blur both frames with a sigma of your choice
        sigma = 4;
        neighborhood_size = 51;
        padding = (neighborhood_size - 1)/2;
        
        % Use a Gaussian to weight each neighbor
        gaussian = fspecial('gaussian', neighborhood_size, (neighborhood_size - 1)/4);

        frame1_blurred = imgaussfilt(frame_1, sigma);
        frame2_blurred = imgaussfilt(frame_2, sigma);
        
        % Get the gradient (first partial derivatives) of the first image
        [dx,dy] = gradient(double(frame1_blurred));
        
        % Pad both frames and the partial derivative matrices
        frame1_padded = padarray(frame1_blurred,[padding padding],0,'both');
        frame2_padded = padarray(frame2_blurred,[padding padding],0,'both');
        dx = padarray(dx,[padding padding],0,'both');
        dy = padarray(dy,[padding padding],0,'both');

        % Iterate through each pixel in the first frame
        for x = 1 + padding:M + padding
            for y = 1 + padding:N + padding
                % Create the second moment matrix for this pixel and the
                % matrix on the RHS of the given equation
                SMM = zeros(2,2);
                RHS = zeros(2,1);
                
                % For each pixel in the neighborhood
                for i = x-padding:x+padding
                    for j = y-padding:y+padding
                        % Update second moment matrix:
                        dx2 = dx(i,j)*dx(i,j);
                        dxdy = dx(i,j)*dy(i,j);
                        dy2 = dy(i,j)*dy(i,j);
                        
                        % Weight according to the Gaussian
                        gaussian_weight = gaussian(i - (x-padding) + 1, j - (y-padding) + 1);

                        dx2_weighted = dx2*gaussian_weight;
                        dxdy_weighted = dxdy*gaussian_weight;
                        dy2_weighted = dy2*gaussian_weight;
                        
                        % Add weighted values to the second moment
                        % matrix
                        SMM(1,1) = SMM(1,1) + dx2_weighted;
                        SMM(1,2) = SMM(1,2) + dxdy_weighted;
                        SMM(2,1) = SMM(2,1) + dxdy_weighted;
                        SMM(2,2) = SMM(2,2) + dy2_weighted;
                            
                        % Update RHS matrix:
                        difference = double(frame1_padded(i,j)) - double(frame2_padded(i,j));

                        dxdiff = difference * dx(i,j) * gaussian_weight;
                        dydiff = difference * dy(i,j) * gaussian_weight;
                            
                        RHS(1,1) = double(RHS(1,1)) + dxdiff;
                        RHS(2,1) = double(RHS(2,1)) + dydiff;
                    end
                end
                               
                % Normalize the second moment matrix and RHS by dividing by
                % the number of pixels in the neighborhood.
                SMM = SMM * (1/(neighborhood_size * neighborhood_size));
                RHS = RHS * (1/(neighborhood_size * neighborhood_size));
   
                % If second moment matrix is not singular, determine [v_x, v_y] of this pixel by multiplying the RHS by
                % the inverse of the second moment matrix
                % (second moment matrix)^-1 * RHS = second moment matrix\RHS
                if (det(SMM) ~= 0)
                    v = SMM\RHS;
                    Vx(x-padding, y-padding) = v(1);
                    Vy(x-padding, y-padding) = v(2);
                else
                    Vx(x-padding, y-padding) = 0;
                    Vy(x-padding, y-padding) = 0;
                end
            end
        end
        
    case "LK_iterative"
        % Gaussian blur both frames with a sigma of your choice
        sigma = 4;
        % Neighborhood size must be an odd number.
        neighborhood_size = 51;
        padding = neighborhood_size + ((neighborhood_size - 1)/2);
        
        % Use a Gaussian to weight each neighbor
        gaussian = fspecial('gaussian', neighborhood_size, (neighborhood_size - 1)/4);
        
        frame1_blurred = imgaussfilt(frame_1, sigma);
        frame2_blurred = imgaussfilt(frame_2, sigma);
        
        % Get the gradient (first partial derivatives) of the first image
         [dx,dy] = gradient(double(frame1_blurred));        
        
        % Pad both frames and the partial derivative matrices
        frame1_padded = padarray(frame1_blurred,[padding padding],0,'both');
        frame2_padded = padarray(frame2_blurred,[padding padding],0,'both');
        dx = padarray(dx,[padding padding],0,'both');
        dy = padarray(dy,[padding padding],0,'both');

        % Iterate through each pixel in the first frame
        for x = 1 + padding:M + padding
            for y = 1 + padding:N + padding                
                % Iterate LK, updating the image according to the
                % new hx and hy until hx and hy are within the threshold
                ngdcenter_x = x;
                ngdcenter_y = y;
                hx = 10;
                hy = 10;
                vx = 0;
                vy = 0;
                iteration_counter = 0;
                iterate_again = true;
                threshold = 0.001;
                
                % Iterate until neighborhood goes out of bounds, has iterated 10 times, or hx and hy are within threshold amount 
                while iterate_again && iteration_counter < 10 && abs(hx) > threshold && abs(hy) > threshold
                    % Create the second moment matrix for this pixel and the
                    % matrix on the RHS of the given equation
                    SMM = zeros(2,2);
                    RHS = zeros(2,1);
 
                    for i = ngdcenter_x-((neighborhood_size - 1)/2):ngdcenter_x+((neighborhood_size - 1)/2)
                        for j = ngdcenter_y-((neighborhood_size - 1)/2):ngdcenter_y+((neighborhood_size - 1)/2)
                            % Update second moment matrix:
                            dx2 = dx(i,j)*dx(i,j);
                            dxdy = dx(i,j)*dy(i,j);
                            dy2 = dy(i,j)*dy(i,j);
                        
                            % Weight according to the Gaussian
                            gaussian_weight = gaussian(i - (ngdcenter_x-((neighborhood_size - 1)/2)) + 1, j - (ngdcenter_y-((neighborhood_size - 1)/2)) + 1);

                            dx2_weighted = dx2*gaussian_weight;
                            dxdy_weighted = dxdy*gaussian_weight;
                            dy2_weighted = dy2*gaussian_weight;
                        
                            % Add weighted values to the second moment
                            % matrix
                            SMM(1,1) = SMM(1,1) + dx2_weighted;
                            SMM(1,2) = SMM(1,2) + dxdy_weighted;
                            SMM(2,1) = SMM(2,1) + dxdy_weighted;
                            SMM(2,2) = SMM(2,2) + dy2_weighted;
                            
                            % Update RHS matrix with weighted values:
                            difference = double(frame1_padded(i,j)) - double(frame2_padded(i,j));

                            dxdiff = difference * dx(i,j) * gaussian_weight;
                            dydiff = difference * dy(i,j) * gaussian_weight;
                            
                            RHS(1,1) = double(RHS(1,1)) + dxdiff;
                            RHS(2,1) = double(RHS(2,1)) + dydiff;
                            
                        end
                    end
                    
                    % Normalize second moment matrix and RHS by dividing by the number of pixels in the neighborhood.
                    RHS = RHS * (1 / (neighborhood_size * neighborhood_size));
                    SMM = SMM * (1 / (neighborhood_size * neighborhood_size));
                    
                    % If second moment matrix is not singular, determine hx, hy of this iteration by multiplying the RHS by
                    % the inverse of the second moment matrix
                    % (second moment matrix)^-1 * RHS = second moment matrix\RHS
                    if (det(SMM) ~= 0)
                        v = SMM\RHS;
                        hx = v(1);
                        hy = v(2);
                        vx = vx + hx;
                        vy = vy + hy;
                    else
                        hx = 0;
                        hy = 0;
                        vx = vx + hx;
                        vy = vy + hy;
                    end
                                        
                    % Update neighborhood location. This is equivalent to
                    % updating the location of the pixels in the frame, but
                    % saves us from updating the entire frame and gradient at each
                    % iteration.
                    if round(ngdcenter_x + hx) >= ((neighborhood_size - 1)/2) + 1 && round(ngdcenter_x + hx) <= M+2*padding - (((neighborhood_size - 1)/2) + 1)
                        ngdcenter_x = round(ngdcenter_x + hx);
                    else
                        iterate_again = false;
                    end
                    if round(ngdcenter_y + hy) >= ((neighborhood_size - 1)/2) + 1 && round(ngdcenter_y + hy) <= N+2*padding - (((neighborhood_size - 1)/2) + 1)
                        ngdcenter_y = round(ngdcenter_y + hy);
                    else
                        iterate_again = false;
                    end
                    
                    iteration_counter = iteration_counter + 1;

                end % End while loop
                
                % Save the final vx and vy for this pixel
                Vx(x-padding, y-padding) = vx;
                Vy(x-padding, y-padding) = vy;
                
            end
        end
       
    case "LK_pyramid"
        % Neighborhood size must be an odd number.
        neighborhood_size = 29;
        padding = neighborhood_size + ((neighborhood_size - 1)/2);
        
        % Use a Gaussian to weight each neighbor
        gaussian = fspecial('gaussian', neighborhood_size, (neighborhood_size - 1)/4);
        
        % Create Gaussian pyramids with n+1 levels. Compute the
        % corresponding derivatives for the first frame at each level.
        n = 4;
        frame1_pyramid =  cell(n+1);
        frame2_pyramid = cell(n+1);
        dx_pyramid = cell(n+1);
        dy_pyramid = cell(n+1);
        
        for i = 0:n
            smooth_image = imgaussfilt(frame_1, 2^i);
            resized_image = imresize(smooth_image, 1/2^i);
            frame1_pyramid(i+1) = {resized_image};
            
            [dx,dy] = gradient(double(resized_image));
            dx_pyramid(i+1) = {dx};
            dy_pyramid(i+1) = {dy};
            
            smooth_image = imgaussfilt(frame_2, 2^i);
            resized_image = imresize(smooth_image, 1/2^i);
            frame2_pyramid(i+1) = {resized_image};
        end
        
        % Starting at coarsest scale, perform iterative LK on each scale.
        % Use the hx, hy found at each scale to update the initial
        % neighborhood location at the next scale.
        coarsest_image = cell2mat(frame1_pyramid(n+1));
        [r,c] = size(coarsest_image);
        Vx_previous = zeros(r,c);
        Vy_previous = zeros(r,c);
        Vx_current = zeros(r,c);
        Vy_current = zeros(r,c);
        
        for scale = n:-1:0
            frame1_blurred = cell2mat(frame1_pyramid(scale+1));
            frame2_blurred = cell2mat(frame2_pyramid(scale+1));
            [r,c] = size(frame1_blurred);

            % Get the gradient (first partial derivatives) of the first image
            dx = cell2mat(dx_pyramid(scale+1));
            dy = cell2mat(dy_pyramid(scale+1));
      
            % Pad both frames and the partial derivative matrices
            frame1_padded = padarray(frame1_blurred,[padding padding],0,'both');
            frame2_padded = padarray(frame2_blurred,[padding padding],0,'both');
            dx = padarray(dx,[padding padding],0,'both');
            dy = padarray(dy,[padding padding],0,'both');
                    
            % Iterate through each pixel of the frames at this scale,
            % performing iterative LK. Use the hx, hy of the previous scale
            % to determine where to center the neighborhood.
            for x = 1 + padding:r + padding
               for y = 1 + padding:c + padding
                    % Choose initial center position by adding the scaled
                    % up hx and hy values found at this pixel's
                    % corresponding position in the previous scale. Make
                    % sure this is not out of bounds.
                    ngdcenter_x = x;
                    ngdcenter_y = y;  
                    hx_previous = Vx_previous(x-padding, y-padding);
                    hy_previous = Vy_previous(x-padding, y-padding);
                    
                    if round(ngdcenter_x + hx_previous) >= ((neighborhood_size - 1)/2) + 1 && round(ngdcenter_x + hx_previous) <= r+2*padding - (((neighborhood_size - 1)/2) + 1)
                        ngdcenter_x = round(ngdcenter_x + hx_previous);
                    else
                        iterate_again = false;
                    end
                    if round(ngdcenter_y + hy_previous) >= ((neighborhood_size - 1)/2) + 1 && round(ngdcenter_y + hy_previous) <= c+2*padding - (((neighborhood_size - 1)/2) + 1)
                        ngdcenter_y = round(ngdcenter_y + hy_previous);
                    else
                        iterate_again = false;
                    end
                    
                    % Begin iterative LK at this scale.         
                    hx = 10;
                    hy = 10;
                    vx = 0;
                    vy = 0;
                    iteration_counter = 0;
                    iterate_again = true;
                    threshold = 0.001;
                
                    % Iterate until neighborhood goes out of bounds, has iterated 10 times, or hx and hy are within threshold amount 
                    while iterate_again && iteration_counter < 10 && abs(hx) > threshold && abs(hy) > threshold
                        % Create the second moment matrix for this pixel and the
                        % matrix on the RHS of the given equation
                        SMM = zeros(2,2);
                        RHS = zeros(2,1);
 
                        for i = ngdcenter_x-((neighborhood_size - 1)/2):ngdcenter_x+((neighborhood_size - 1)/2)
                            for j = ngdcenter_y-((neighborhood_size - 1)/2):ngdcenter_y+((neighborhood_size - 1)/2)
                                % Update second moment matrix:
                                dx2 = dx(i,j)*dx(i,j);
                                dxdy = dx(i,j)*dy(i,j);
                                dy2 = dy(i,j)*dy(i,j);
                        
                                % Weight according to the Gaussian
                                gaussian_weight = gaussian(i - (ngdcenter_x-((neighborhood_size - 1)/2)) + 1, j - (ngdcenter_y-((neighborhood_size - 1)/2)) + 1);

                                dx2_weighted = dx2*gaussian_weight;
                                dxdy_weighted = dxdy*gaussian_weight;
                                dy2_weighted = dy2*gaussian_weight;
                        
                                % Add weighted values to the second moment
                                % matrix
                                SMM(1,1) = SMM(1,1) + dx2_weighted;
                                SMM(1,2) = SMM(1,2) + dxdy_weighted;
                                SMM(2,1) = SMM(2,1) + dxdy_weighted;
                                SMM(2,2) = SMM(2,2) + dy2_weighted;
                            
                                % Update RHS matrix with weighted value:
                                difference = double(frame1_padded(i,j)) - double(frame2_padded(i,j));

                                dxdiff = difference * dx(i,j) * gaussian_weight;
                                dydiff = difference * dy(i,j) * gaussian_weight;
                            
                                RHS(1,1) = double(RHS(1,1)) + dxdiff;
                                RHS(2,1) = double(RHS(2,1)) + dydiff;
                            
                            end
                        end
                        
                        % Normalize second moment matrix and RHS by
                        % dividing by the number of pixels in the
                        % neighborhood.
                        RHS = RHS * (1 / (neighborhood_size * neighborhood_size));
                        SMM = SMM * (1 / (neighborhood_size * neighborhood_size));
                    
                        % If second moment matrix is not singular, determine hx, hy of this iteration by multiplying the RHS by
                        % the inverse of the second moment matrix
                        % (second moment matrix)^-1 * RHS = second moment matrix\RHS
                        if (det(SMM) ~= 0)
                            v = SMM\RHS;
                            hx = v(1);
                            hy = v(2);
                            vx = vx + hx;
                            vy = vy + hy;
                        else
                            hx = 0;
                            hy = 0;
                            vx = vx + hx;
                            vy = vy + hy;
                        end
                    
                        iteration_counter = iteration_counter + 1;
                        
                        % Update neighborhood center for the next
                        % iteration at this scale, making sure it does not go out of bounds.  
                        if round(ngdcenter_x + hx) >= ((neighborhood_size - 1)/2) + 1 && round(ngdcenter_x + hx) <= r+2*padding - (((neighborhood_size - 1)/2) + 1)
                            ngdcenter_x = round(ngdcenter_x + hx);
                        else
                            iterate_again = false;
                        end
                        if round(ngdcenter_y + hy) >= ((neighborhood_size - 1)/2) + 1 && round(ngdcenter_y + hy) <= c+2*padding - (((neighborhood_size - 1)/2) + 1)
                            ngdcenter_y = round(ngdcenter_y + hy);
                        else
                            iterate_again = false;
                        end
                        
                    end % End while loop
                
                    % Add the new vx and vy to the previously found ones 
                    % and ave the final vx and vy for this pixel
                    Vx_current(x-padding, y-padding) = vx + Vx_previous(x-padding, y-padding);
                    Vy_current(x-padding, y-padding) = vy + Vy_previous(x-padding, y-padding);

               end                  
            end % End iterating through each pixel of a scale
            
            % Scale up Vx_current and Vy_current for the next scale to
            % use. Create new Vx_current and Vy_current for the next
            % scale.
            if (scale > 0)
                Vx_previous = imresize(Vx_current, 2);
                Vy_previous = imresize(Vy_current, 2);
                Vx_current = zeros(2*r, 2*c);
                Vy_current = zeros(2*r, 2*c);
            end
            
        end % End iterating through scales

        % Return the final values of hx and hy found
        Vx = Vx_current;
        Vy = Vy_current;
 
        end
end
