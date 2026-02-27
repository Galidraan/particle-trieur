from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()
long_description = (here / 'README.md').read_text(encoding='utf-8')

setup(
    name='miso',
    version='4.0.0',
    description='Python scripts for training CNNs for particle classification',
    long_description=long_description,
    long_description_content_type='text/markdown',
    author='Ross Marchant',
    author_email='ross.g.marchant@gmail.com',
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: Science/Research',
    ],
    keywords='microfossil, cnn',
    python_requires='>=3.10,<=3.12',
    packages=find_packages(),
    install_requires=['tensorflow>=2.15,<2.18',
                      'image-classifiers>=1.0.0',
                      'lxml>=5.1.0',
                      'matplotlib>=3.8',
                      'numpy>=1.26,<2.0',
                      'pandas>=2.1',
                      'Pillow>=10.2',
                      'imagecodecs>=2024.1',
                      'scikit-image>=0.22',
                      'scikit-learn>=1.3',
                      'scipy>=1.11',
                      'segmentation-models>=1.0.1',
                      'dill>=0.3.7',
                      'flask>=3.0',
                      'itsdangerous>=2.1',
                      'tqdm>=4.66',
                      'openpyxl>=3.1',
                      'imbalanced-learn>=0.11',
                      'onnx>=1.14',
                      'tf2onnx>=1.16',
                      'protobuf>=3.20',
                      'cleanlab>=2.5',
                      'packaging>=23.2',
                      'marshmallow_dataclass>=8.6',
                      'opencv-python>=4.9',
                      'onnxruntime>=1.17'],
    url='https://github.com/microfossil/particle-classification',
    license='MIT',
    project_urls={  # Optional
        'Source': 'https://github.com/microfossil/particle-classification',
        'Paper': 'https://jm.copernicus.org/articles/39/183/2020/',
    },
)
