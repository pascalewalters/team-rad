## Setting up tensorflow object detection

### Install conda

Conda allows you to create an environment for development to keep dependencies organized for various projects.

```
cd ~
curl -O https://conda.io/miniconda.html
bash Miniconda3-latest-MacOSX-x86_64.sh
```

Follow the instructions on the prompt. Just leave everything as the default.

Test installation by creating a new environment:

```
conda create --name fydp
source activate fydp
```

### Install the framework build of python

This is required on MacOS to be able to use matplotlib.

```
conda install python.app
```

### Install tensorflow

Find out which version of python you have (it's probably 3.x):

```
python --version
```

For python 2.x:

```
python -m pip install --upgrade https://storage.googleapis.com/tensorflow/mac/cpu/tensorflow-1.11.0-py2-none-any.whl
```

For python 3.x:

```
python -m pip install --upgrade https://storage.googleapis.com/tensorflow/mac/cpu/tensorflow-1.11.0-py3-none-any.whl
```

### Clone the repo

```
git clone https://github.com/tensorflow/models.git
```

Install dependencies:

```
pip install --user Cython
pip install --user contextlib2
pip install --user pillow
pip install --user lxml
pip install --user jupyter
pip install --user matplotlib
```

```
git clone https://github.com/cocodataset/cocoapi.git
cd cocoapi/PythonAPI
make
cp -r pycocotools <path_to_models_repo>/research/
```

```
brew install protobuf

# From models/research/
protoc object_detection/protos/*.proto --python_out=.
```

```
# From models/research/
export PYTHONPATH=$PYTHONPATH:`pwd`:`pwd`/slim
```

### Test the installation

```
# From models/research/
pythonw object_detection/builders/model_builder_test.py
```

### Get object detection working with our frames

Move `object_detection_test.py` from this repo into `models/research/object_detection`

Open the file and make sure all paths are correct (`image_dir` on line 121 and the for loop condition on line 131).

Run it:

```
pythonw object_detection/object_detection_test.py
```
