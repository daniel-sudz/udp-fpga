# Software

The software allows chunking a `.wav` audio file of bitrate 44.1kHz to be streamed over ethernet. 
The configuration and setup can be looked up in the `build` file. The audio program includes the following arguments:
`out/src/audio <wav file> <eth interface>`. For example: `out/src/audio $DIR/src/file.wav enp0s31f6`. A sample build file is documented below. 


## compile 
```bash
rm -rf out
mkdir out

cd out
cmake ..
make
cd ..
```

## run
```bash
out/src/audio $DIR/src/sound.wav enp0s31f6
```
