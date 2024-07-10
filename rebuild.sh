#!/bin/bash
pkill -f "nlogout"

# install the nim language to compile nlogout
sudo pacman -S nim --noconfirm --needed

# Installl modules used in nlogout
yes | nimble install parsetoml
yes | nimble install nigui

# xsetroot -name ""  <--- why?

# Compile nlogout to .config/nlogout/nlogout (will make the directory if it doesn't exsist)
nim compile --define:release --opt:size --app:gui --outdir:$HOME/.config/nlogout/ src/nlogout.nim 

#Copy config.toml if its not already in the users .config/nlogout
if [[ ! -e $HOME/.config/nlogout/config.toml ]]; then
    cp config.toml $HOME/.config/nlogout/config.toml   
fi

#Copy themes across to .config/logout/
if [[ ! -e $HOME/.config/nlogout/themes ]]; then
    cp -rv ./themes $HOME/.config/nlogout/themes   
fi




