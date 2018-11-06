import cv2
import numpy as np
import time

#path to classifier
#path to video file
cascade_src = 'myhaar.xml'
# video_src = 'video//drugi.mkv'
# video_src = 'video//Trimmed.mov'
# video_src = 'video//SpeedTest_Landscape.mov'
video_src = '/Users/jspope/PycharmProjects/team-rad/CMS/video/SpeedTest2_Landscape.mov'


#
#read video
#load classifier from file
cap = cv2.VideoCapture(video_src)
car_cascade = cv2.CascadeClassifier(cascade_src)

fps = 0

#defining borders of ROI
x1 = 0
y1 = 160
v = 720
hc = v - y1

#reading video frame by frame
while True:
	#starting time of loop iteration
	start_time = time.time()

	#read frame
	ret, img = cap.read()
	if (type(img) == type(None)):
		break

	#crop frame to get ROI
	# img = img[y1:y1+hc, x1:x1+720]
	# this is 160:560 (400 height) and 0:720 (720 width)
	desired_w = 400
	desired_h = 400
	if (cap.get(3) < desired_w and cap.get(4)< desired_h):
		img = img[0:int(cap.get(4)), 0:int(cap.get(3))]

	elif (cap.get(3) < desired_w):
		new_h_start = int((cap.get(4) - desired_h) / 2)
		new_h_end = int(cap.get(4)-new_h_start)
		img = img[new_h_start:new_h_end, 0:int(cap.get(3))]

	elif (cap.get(4) < desired_h):
		new_w_start = int((cap.get(3) - desired_w) / 2)
		new_w_end = int(cap.get(3)-new_w_start)
		img = img[0:int(cap.get(4)), new_w_start:new_w_end]

	else:
		new_w_start = int((cap.get(3) - desired_w) / 2)
		new_w_end = int(cap.get(3)-new_w_start)
		new_h_start = int((cap.get(4) - desired_h) / 2)
		new_h_end = int(cap.get(4)-new_h_start)
		img = img[new_h_start:new_h_end, new_w_start:new_w_end]

	# print('new_w_start: ' + str(new_w_start))
	# print('new_w_end: ' + str(new_w_end))
	# img = img[0:1080, 610:1310]
	# width = cap.get(3)  # float
	# print ('Width: ' + str(width))
	# height = cap.get(4)  # float
	# print ('Height: ' + str(height))


	#convert to gray scale
	gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

	#Detect objects with different dimensions in frame
	#output of function is list of rectangles
	#parameters: image, scaleFactior, minNeighbors, flags, minSize, maxSize
	cars = car_cascade.detectMultiScale(gray, 1.1, 13, 0, (24, 24))

	#drawing rectangle around detected object
	#defining regions where object will show up
	for (x, y, w, h) in cars:
		cv2.rectangle(img, (x, y), (x+w, y+h), (0, 0, 255), 2)

	#calculation of frame rate
	fps = 1.0/(time.time() - start_time)

	#showing video with detected object
	cv2.putText(img, "FPS: " + str(int(fps)), (desired_w-100, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.75, (0, 0, 255), 2)
	cv2.imshow('video', img)

	#press "esc" key to terminate
	if cv2.waitKey(33) == 27:
		break;

cv2.destroyAllWindows()
cap.release()
