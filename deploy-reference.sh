#!/bin/sh

# Push all png 

set -e

cd "${TRAVIS_BUILD_DIR}"

openssl aes-256-cbc -K $encrypted_8843021b8580_key -iv $encrypted_8843021b8580_iv -in ./deploy_key.enc -out ./deploy_key -d
chmod 600 ./deploy_key
eval `ssh-agent -s`
cp ./deploy_key $HOME/.ssh/id_rsa

git config --global push.default simple
git config user.name "Travis CI"
git config user.email "travis@travis-ci.org"

git checkout "${TRAVIS_BRANCH}"
git add --all
git commit -m "Update reference png for commits: ${TRAVIS_COMMIT_RANGE}" -m "Travis build: ${TRAVIS_BUILD_NUMBER} [ci skip]"
rm .git/hooks/pre-push # from https://github.com/git-lfs/git-lfs/issues/2291#issuecomment-305887405
GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa" git lfs push --all "git@github.com:${TRAVIS_REPO_SLUG}.git" "${TRAVIS_BRANCH}"
GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa" git push "git@github.com:${TRAVIS_REPO_SLUG}.git" "${TRAVIS_BRANCH}"
