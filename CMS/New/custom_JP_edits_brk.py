import math as m
import statistics as st
import time

import cv2
import matplotlib.pyplot as plt
import numpy as np

# import customs scripts
from crop_video import crop

carCascade = cv2.CascadeClassifier('myhaar.xml')
# video = cv2.VideoCapture('video//SpeedTest2_Landscape.MOV')
# video = cv2.VideoCapture('video//prvi.mkv')

video = cv2.VideoCapture('video//Trimmed.mov')

# video = cv2.VideoCapture('video//Sedan_downhill.MOV')
# video = cv2.VideoCapture('video//Truck_stopsign.MOV')

# calculate momentary time to collision
def momentary_ttc(w1, w2, time):
    ttc = time / ((w2 / w1) - 1)
    return ttc


# calculate acceleration adjusted time to collision
# def accel_ttc():

# detect vehicles using Haar cascade classifier
def detect_vehicles(grey_img, scaleFactor, minNeighbors):
    # detectMultiScale(image[, scaleFactor[, minNeighbors[, flags[, minSize[, maxSize]]]]])
    detected_vehicles = carCascade.detectMultiScale(grey_img, scaleFactor, minNeighbors)

    return detected_vehicles


# def tracker():

def read_video():
    red = (0, 0, 255)
    blue = (255, 0, 0)
    green = (0, 255, 0)

    currentCarID = 0

    carTracker = {}
    width1 = {}
    width2 = {}
    time1 = {}
    time2 = {}
    tm = {}
    # tm[0] = 'unknown'

    desired_w = 800
    desired_h = 700

    new_w_start, new_w_end, new_h_start, new_h_end = crop(video, desired_w, desired_h)

    tmp = 10
    frameCounter = 0
    # read video
    while True:
        rc, image = video.read()
        if type(image) == type(None):
            break

        # crop image
        cropped = image[new_h_start:new_h_end, new_w_start:new_w_end]

        # convert to grey scale image
        grey = cv2.cvtColor(cropped, cv2.COLOR_BGR2GRAY)

        # detect vehicles every x frame as defined by me
        if (frameCounter % tmp == 0):
            cars = detect_vehicles(grey, 1.25, 5)
            #
            for (_x, _y, _w, _h) in cars:
                x_obj = int(_x)
                y_obj = int(_y)
                w_obj = int(_w)
                h_obj = int(_h)
                cv2.rectangle(cropped, (x_obj, y_obj), (x_obj + w_obj, y_obj + h_obj), green, 2)
                # print("detected car {}".format((_x, _y, _w, _h)))

                delta_x_obj = x_obj + 0.5 * w_obj
                delta_y_obj = y_obj + 0.5 * h_obj

                matchCarID = None

                # iterate through trackers
                for tracked_id in carTracker:
                    trackedPosition = carTracker[tracked_id].update(cropped)

                    if (trackedPosition[0] == 1):
                        x_t, y_t, w_t, h_t = trackedPosition[1]

                        delta_x_t = x_t + 0.5 * w_t
                        delta_y_t = y_t + 0.5 * h_t
                        # print("tracked car {}".format(trackedPosition[1]))
                        # if condition is true, detected object already have tracker
                        if ((x_t <= delta_x_obj <= (x_t + w_t)) and
                                (y_t <= delta_y_obj <= (y_t + h_t)) and
                                (x_obj <= delta_x_t <= (x_obj + w_obj)) and
                                (y_obj <= delta_y_t <= (y_obj + h_obj))):
                            matchCarID = tracked_id

                if (matchCarID) is None:
                    bbox = (x_obj, y_obj, w_obj, h_obj)
                    if ((bbox[0] + bbox[2] < (desired_w / 2)) and
                            (bbox[1] < (desired_h / 4))):  # and bbox[0] > 70:
                        tracker = cv2.TrackerMedianFlow_create()
                        tracker.init(cropped, bbox)
                        carTracker[currentCarID] = tracker
                        # previous_location[currentCarID] = bbox

                        # width1[currentCarID] = bbox[2]
                        width1[currentCarID] = w_obj
                        # get time at which car is being tracked
                        time1[currentCarID] = time.time()
                        #time1[currentCarID] = frameCounter / video.get(5)
                        currentCarID = currentCarID + 1

                        # print("Added tracker {}".format(bbox))
                        cv2.rectangle(cropped, (bbox[0], bbox[1]), (bbox[0] + bbox[2], bbox[1] + bbox[3]), red, 2)

        if (frameCounter % 2 == 0):
            for tracked_id in carTracker:
                trackedPosition = carTracker[tracked_id].update(cropped)

                if (trackedPosition[0] == 1):
                    x_t, y_t, w_t, h_t = trackedPosition[1]
                    cv2.rectangle(cropped, (bbox[0], bbox[1]), (bbox[0] + bbox[2], bbox[1] + bbox[3]), blue, 2)

                width2[tracked_id] = w_t
                time2[tracked_id] = time.time()
                #time2[tracked_id] = frameCounter / video.get(5)

                delta_t = time2[tracked_id] - time1[tracked_id]

                #print("width 1 for {_id} is {width}".format(_id=tracked_id,
#                                                            width=width1[tracked_id]))
                #print("width 2 for {_id} is {width}".format(_id=tracked_id,
#                                                            width=width2[tracked_id]))

                #print("delta t is {time}".format(time=delta_t))
                if (width1[tracked_id] < width2[tracked_id] and width2[tracked_id] != 0 and width1[tracked_id] != 0):
                    t_float = momentary_ttc(width1[tracked_id], width2[tracked_id], delta_t)


                    # if (tracked_id> 2 and (t_float  > 7 or t_float > tm[tracked_id-1]) ):
                    #     t = 'unknown'
                    #     tm[tracked_id] = t_float
                    # else:
                    #     t = t_float
                    #     tm[tracked_id] = t
                    # print(t)
                    print(tm[tracked_id])
                    #print("TTC for {_id} is {time}".format(_id=tracked_id,
                                                           #time=t))

                width1[tracked_id] = width2[tracked_id]
                time1[tracked_id] = time2[tracked_id]
                cv2.putText(cropped, 'TTC: ' + str(t_float) + ' s.', (20, 40),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.75, (0, 0, 255), 3)
        frameCounter = frameCounter + 1
        # wait for esc to terminate
        if cv2.waitKey(33) == 27:
            break
        cv2.imshow('image', cropped)

    # close all open
    cv2.destroyAllWindows()


read_video()
# out = cv2.VideoWriter('output.avi', -1, 20.0, (640,480))