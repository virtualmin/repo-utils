#!/bin/sh
shopt -s dotglob

rsync -avz /home/build/result/* software2@software2.virtualmin.com:/home/software2/public_html/
rsync -avz /home/build/result/* software3@software3.virtualmin.com:/home/software3/public_html/
