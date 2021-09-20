#!/usr/bin/env sh
docker run -itd -p 8888:8888 -v ~/.aws:/root/.aws:ro \
  -v $(pwd)/notebooks:/root/notebook:rw --name spark3 --privileged \
  spark3
