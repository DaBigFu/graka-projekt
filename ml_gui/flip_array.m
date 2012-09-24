function array_out = flip_array( array_in )
%FLIP_ARRAY Summary of this function goes here
%   Detailed explanation goes here
reshaped = reshape(array_in, 768 , 4 ,768);
for i = 1:1:768
 reshaped(:,:,i) = rot90(reshaped(:,:,i),2);
end
array_out = reshape(reshaped,768,3072);

end

