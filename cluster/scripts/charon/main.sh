#!/bin/bash

./handle-file-import.sh

./restart-container-on-file-upload.sh

./run-charon.sh
