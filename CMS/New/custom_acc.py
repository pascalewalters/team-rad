import math as m
import statistics as st
import time

import cv2
import matplotlib.pyplot as plt
import numpy as np

# import customs scripts
from crop_video import crop

carCascade = cv2.CascadeClassifier('myhaar.xml')
video = cv2.VideoCapture('video//SpeedTest2_Landscape.MOV')
# video = cv2.VideoCapture('video//prvi.mkv')
# video = cv2.VideoCapture('video//Sedan_downhill.MOV')
# video = cv2.VideoCapture('video//Truck_stopsign.MOV')
# video = cv2.VideoCapture('video/Trimmed.mov')

desired_w = 1000
desired_h = 350


# out = cv2.VideoWriter('output.avi', -1, 20.0, (desired_w, desired_h))

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


def acceleration_ttc(tm1, tm2, time, C):
    ttc = tm2 * ((1 - m.sqrt(1 - 2 * C)) / C)

    return ttc


# def tracker():

def read_video():
    frameRate = video.get(5)
    red = (0, 0, 255)
    blue = (255, 0, 0)
    green = (0, 255, 0)

    currentCarID = 0

    carTracker = {}
    width1 = {}
    width2 = {}
    time1 = {}
    time2 = {}
    # momentary time to collision
    t_m1 = {}
    t_m2 = {}

    new_w_start, new_w_end, new_h_start, new_h_end = crop(video, desired_w, desired_h)

    tmp = 15
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
            cars = detect_vehicles(grey, 1.15, 15)
            #
            for (_x, _y, _w, _h) in cars:
                x_obj = int(_x)
                y_obj = int(_y)
                w_obj = int(_w)
                h_obj = int(_h)
                # cv2.rectangle(cropped, (x_obj, y_obj), (x_obj + w_obj, y_obj + h_obj), green, 2)
                # print("detected car {}".format((_x, _y, _w, _h)))

                delta_x_obj = x_obj + 0.5 * w_obj
                delta_y_obj = y_obj + 0.5 * h_obj

                matchCarID = None

                # iterate through trackers
                for tracked_id in carTracker:
                    trackedPosition = carTracker[tracked_id].update(cropped)

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
                        # time1[currentCarID] = time.time()
                        time1[currentCarID] = frameCounter / frameRate
                        currentCarID = currentCarID + 1

                # print("Added tracker {}".format(bbox))
                # cv2.rectangle(cropped, (bbox[0], bbox[1]), (bbox[0] + bbox[2], bbox[1] + bbox[3]), red, 2)

        if (frameCounter % 15 == 0):
            for tracked_id in carTracker:
                trackedPosition = carTracker[tracked_id].update(cropped)

                x_t, y_t, w_t, h_t = trackedPosition[1]

                width2[tracked_id] = w_t
                # time2[tracked_id] = time.time()
                time2[tracked_id] = frameCounter / frameRate
                delta_t = time2[tracked_id] - time1[tracked_id]

                # print("width 1 for {_id} is {width}".format(_id = tracked_id,
                #											width = width1[tracked_id]))
                # print("width 2 for {_id} is {width}".format(_id = tracked_id,
                #											width = width2[tracked_id]))

                # print("delta t is {time}".format(time=delta_t))

                if (width1[tracked_id] != width2[tracked_id] and width1[tracked_id] != 0):
                    t = momentary_ttc(width1[tracked_id], width2[tracked_id], delta_t)
                    t_m2[tracked_id] = t
                    if (tracked_id in t_m1 and tracked_id in t_m2 and t_m1[tracked_id] is not None and t_m2[
                        tracked_id] is not None):
                        C = ((t_m2[tracked_id] - t_m1[tracked_id]) / delta_t) + 1
                        if (t_m1[tracked_id] is not None and t_m2[tracked_id] is not None and C < 0):
                            # print(t_m2[tracked_id])
                            # print(t_m1[tracked_id])
                            t_a = acceleration_ttc(t_m1[tracked_id], t_m2[tracked_id], delta_t, C)
                            # print("at frame {f} calculates t_a = {t}".format(f=frameCounter, t=t_a))
                            print(t_m2[tracked_id])
                            print(t_a)
                            print(frameCounter)
                            # print("at frame {f} calculates t_m = {t}".format(f=frameCounter, t=t_m2[tracked_id]))

                        else:
                            t_a = t
                        # print("TTC for {_id} is {time}".format(_id = tracked_id,
                        #										time = t))
                        cv2.putText(cropped, 'TTC: ' + str(int(t_a)) + ' s.', (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.75,
                                    (0, 0, 255), 3)
                else:
                    t_m2[tracked_id] = None

                # update values
                width1[tracked_id] = width2[tracked_id]
                time1[tracked_id] = time2[tracked_id]

                t_m1[tracked_id] = t_m2[tracked_id]

        frameCounter = frameCounter + 1
        # wait for esc to terminate
        if cv2.waitKey(33) == 27:
            break
        cv2.imshow('image', cropped)
    # close all open
    cv2.destroyAllWindows()


time1 = time.time()
read_video()
time2 = time.time()

# print(time2 - time1)
