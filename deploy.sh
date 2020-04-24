#!/bin/bash

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="${REPO_ROOT}/src"

echo "Deploying updates to GitHub..."

echo "- Building site"
cd ${SRC_DIR}
HUGO_ENV=production hugo -v
cd ${REPO_ROOT}

echo "- Adding changes to git"
git add ./docs

MESSAGE="Rebuilding docs for `date` deployment"
if [ $# -eq 1 ] ; then
    MESSAGE="$1"
fi

echo "- Committing changes to git"
git commit -m "$MESSAGE"

echo "- Pushing changes to git"
git push origin master

echo "Deployment complete"
