#!/bin/sh
# note working directory path still relative from the root as this script is executed inside .travis.yml
security create-keychain -p "$TRAVIS_KEYCHAIN_PASSWORD" ios-build.keychain
security default-keychain -s ios-build.keychain
security unlock-keychain -p "$TRAVIS_KEYCHAIN_PASSWORD" ios-build.keychain
security set-keychain-settings -t 3600 -l ~/Library/Keychains/ios-build.keychain

security import ./ci/certs/apple.cer -k ios-build.keychain -A
security import ./ci/certs/potatso-development.cer -k ios-build.keychain -A
security import ./ci/certs/potatso-development.p12 -k ios-build.keychain -P "$P12_PASSWORD" -A