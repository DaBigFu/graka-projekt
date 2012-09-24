function array_out = flip_array( array_in )
%FLIP_ARRAY Summary of this function goes here
%   Detailed explanation goes here
reshaped = reshape(array_in, 768 , 4 ,768);
for i = 1:1:768
 reshaped(:,:,i) = rot90(reshaped(:,:,i),2);
end
reshaped = reshape(reshaped,768,3072);
colors_flipped = reshaped;
colors_flipped(1:3:768,:) = reshaped(3:3:768,:);
colors_flipped(3:3:768,:) = reshaped(1:3:768,:);
array_out = colors_flipped;
end

