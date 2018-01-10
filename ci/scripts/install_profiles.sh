#/bin/sh
# note working directory path still relative from the root as this script is executed inside .travis.yml
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp ./ci/profiles/main-development.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
cp ./ci/profiles/ex-packettunnel-development.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
cp ./ci/profiles/ex-todaywidget-development.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/