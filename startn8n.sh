#!/bin/bash

docker run -d --name n8ndata \
  -p 5681:5678 \
  -v n8ndata:/home/node/.n8n \
  n8nio/n8n:latest
