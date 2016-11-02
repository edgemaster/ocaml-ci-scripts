#!/bin/sh
# From https://github.com/simonjbeaumont/ocaml-travis-gh-pages

set -e
# Make sure we're not echoing any sensitive data
set +x

# Initialise used variables to prevent errors with "-o nounset"
DOCDIR=.gh-pages
${KEEP:=}         # If set to some string, will delete the DOCDIR on script termination

eval `opam config env`
./configure --enable-docs
make doc

if [ -z "$TRAVIS" -o "$TRAVIS_PULL_REQUEST" != "false" ]; then
  echo "This is not a push Travis-ci build, doing nothing..."
  exit 0
else
  echo "Updating docs on Github pages..."
fi

DOCDIR=.gh-pages
if [ -n "$KEEP" ]; then trap "rm -rf $DOCDIR" EXIT; fi
rm -rf $DOCDIR

REDACT_PATTERN=""

# Error out if $GH_TOKEN and $DH_DEPLOY_KEY are empty or unset
if [ -n "$GH_TOKEN" ]; then
  REPO="https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git"
  REDACT_PATTERN="s/$GH_TOKEN/!REDACTED!/g"
elif [ -n "$GH_DEPLOY_KEY" ]; then
  # $GH_DEPLOY_KEY should be inserted into project settings quoted and with newlines escaped as \n
  eval `ssh-agent`
  printf "%b" "$GH_DEPLOY_KEY" | ssh-add /dev/stdin
  REPO="git@github.com:${TRAVIS_REPO_SLUG}.git"
else
  echo "GH_TOKEN or GH_DEPLOY_KEY variable must be set"
  exit 1
fi

git clone $REPO $DOCDIR 2>&1 | sed -e "$REDACT_PATTERN"
git -C $DOCDIR checkout gh-pages || git -C $DOCDIR checkout --orphan gh-pages

cp _build/*.docdir/* $DOCDIR

git -C $DOCDIR config user.email "travis@travis-ci.org"
git -C $DOCDIR config user.name "Travis"
git -C $DOCDIR add .
git -C $DOCDIR commit --allow-empty -m "Travis build $TRAVIS_BUILD_NUMBER pushed docs to gh-pages"
git -C $DOCDIR push origin gh-pages 2>&1 | sed -e "$REDACT_PATTERN"

if [ -n "$GH_DEPLOY_KEY" ]; then eval `ssh-agent -k`; fi
