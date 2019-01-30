def crop(video, desired_w, desired_h):
    if (video.get(3) < desired_w and video.get(4) < desired_h):
        new_w_start = 0
        new_w_end = int(video.get(3))
        new_h_start = 0
        new_h_end = int(video.get(4))

    elif (video.get(3) < desired_w):
        new_h_start = int((video.get(4) - desired_h) / 2)
        new_h_end = int(video.get(4) - new_h_start)
        new_w_start = 0
        new_w_end = int(video.get(3))

    elif (video.get(4) < desired_h):
        new_h_start = 0
        new_h_end = int(video.get(4))
        new_w_start = int((video.get(3) - desired_w) / 2)
        new_w_end = int(video.get(3) - new_w_start)

    else:
        new_w_start = int((video.get(3) - desired_w) / 2)
        new_w_end = int(video.get(3) - new_w_start)
        new_h_start = int((video.get(4) - desired_h) / 2)
        new_h_end = int(video.get(4) - new_h_start)

    return new_w_start, new_w_end, new_h_start, new_h_end
