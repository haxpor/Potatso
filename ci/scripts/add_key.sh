#!/bin/sh
security create-keychain -p "$TRAVIS_KEYCHAIN_PASSWORD" ios-build.keychain
security default-keychain -s ios-build.keychain
security unlock-keychain -p "$TRAVIS_KEYCHAIN_PASSWORD" ios-build.keychain
security set-keychain-settings -t 3600 -l ~/Library/Keychains/ios-build.keychain

security import ../certs/apple.cer -k ios-build.keychain -A
security import ../certs/potatso-development.cer -k ios-build.keychain -A
security import ../certs/potatso-development.p12 -k ios-build.keychain -P "$P12_PASSWORD" -A