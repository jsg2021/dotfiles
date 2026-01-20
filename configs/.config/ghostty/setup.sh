#!/usr/bin/env sh
PLATFORM=linux
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM=macos
fi

CWD=$(dirname -- "$(readlink -f -- "$0")")
(
  cd $CWD;

  if [ -f platform-override ]; then
    TARGET=$(readlink platform-override);
    if [ "$TARGET" != "$PLATFORM" ]; then
      echo "broken symlink detected, removing"
      rm platform-override  
    fi
  fi
  if [ ! -f platform-override ]; then
    echo "creating platform-override symlink to $PLATFORM"
    ln -s $PLATFORM platform-override
  fi
)
