% read in video
path_in = '../New/video/SpeedTest2_Landscape.MOV';
video = VideoReader(path_in);

path_out = 'SpeedTest2_Landscape-crop_1000_350.avi';

% to play video
% implay('../New/video/SpeedTest2_Landscape.MOV')


% video cropper

desired_w = 1000;
desired_h = 350;

new_w_start = (video.width - desired_w) / 2;
new_h_start = (video.height - desired_h) / 2;

num_frames = round(video.frameRate * video.Duration, 0);


%     vid1=VideoReader('V1.avi');
%     n=video.NumberOfFrames;
    writerObj1 = VideoWriter(path_out);
    open(writerObj1);
    for i=1:num_frames
      im=read(video,i);
%       im=imresize(im,0.5);
      imc=imcrop(im,[new_w_start new_h_start desired_w desired_h]);% The dimention of the new video
      img=rgb2gray(im);
%       [a,b]=size(img);
      imc=imresize(imc,[desired_h,desired_w]);
      writeVideo(writerObj1,imc);  
    end
    close(writerObj1)
    
    
%     vid1 = VideoReader(path_out);
   implay(path_out)