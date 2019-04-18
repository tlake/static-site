#!/bin/bash

echo "Deploying updates to GitHub..."

cd ./src
hugo
cd ..

git add ./docs

MESSAGE="Rebuilding docs for `date` deployment"
if [ $# -eq 1 ] ; then
    MESSAGE="$1"
fi

git commit -m "$MESSAGE"

git push origin master
