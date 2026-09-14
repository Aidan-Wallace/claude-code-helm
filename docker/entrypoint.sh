#!/bin/sh
set -e

# A PVC mounted at $HOME starts empty and shadows the base image's baked-in
# dotfiles (oh-my-zsh, .bashrc, etc.) - reseed once from the build-time
# snapshot so a fresh volume isn't bare. .oh-my-zsh presence is the marker.
if [ ! -e "$HOME/.oh-my-zsh" ] && [ -d /opt/skel-codespace ]; then
  cp -a /opt/skel-codespace/. "$HOME"/
  chown -R codespace:codespace "$HOME"
fi

if [ -n "$DOCKER_HOST" ]; then
  echo "DOCKER_HOST=$DOCKER_HOST" >> /etc/environment
fi

exec "$@"
