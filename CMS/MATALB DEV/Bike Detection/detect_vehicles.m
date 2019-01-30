trafficVid = VideoReader('/Users/jspope/Desktop/BME 461 - FYDP/oct-6 - data/Sedan_downhill [Oct.6,2018].MOV');

%  more data - like duration
%  get(trafficVid)

%  to play back the video
% implay('/Users/jspope/Desktop/BME 461 - FYDP/oct-6 - data/Sedan_downhill [Oct.6,2018].MOV')



road_conditions = rgb2gray(read(trafficVid,721));
% imextendedmax returns a binary image that identifies regions with intensity
% values above a specified threshold, called regional maxima
remove_road = imextendedmax(road_conditions, 50);
% 35 is the arbritray pixel intensity value chosen

%frame of interest
% figure(1)
% imshow(road_conditions)

%intensity removed pixels (0) and remaining pixels white (1)
figure(2)
imshow(remove_road)

% Because the lane-markings are long and thin objects, use a disk-shaped structuring 
% element with radius corresponding to the width of the lane markings. You can use the pixel 
% region tool in implay to estimate the width of these objects. 
% For this example, set the value to 2.

sedisk = strel('disk',3);
noSmallStructures = imopen(remove_road, sedisk);
imshow(noSmallStructures)