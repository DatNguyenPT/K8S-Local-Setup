#!/bin/bash

sudo apt update
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.10 python3.10-venv python3.10-dev

python3.10 -m venv kubespray-py10
source kubespray-py10/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
