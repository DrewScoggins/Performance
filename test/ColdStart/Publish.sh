#!/bin/bash

repoRoot=`git rev-parse --show-toplevel`

## run "build pre-clean" to ensure we have the lastest dotnet
## currently this line is not work, need to fix it
## $repoRoot/build.sh pre-clean

# Set targetApp name and workspace
scriptRoot="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $scriptRoot/SetEnv.sh

if [ -z "$targetApp" ]; then
    echo "Target application is not set"
    return
fi

if [ -z "$workspace" ]; then
    echo "Workspace dir is not set"
    return
fi

if [ -z "$outputFile" ]; then
    echo "Output file is not set"
    return
fi

if [ ! -d "$workspace" ]; then
    echo "Workspace $workspace does not exist"
    return
fi

appLocation="$repoRoot/testapp/$targetApp"

if [ ! -d "$appLocation" ]; then
    echo "$appLocation is not a valid performance app"
    return
fi

## publish targeted application
pushd $appLocation
~/.dotnet/dotnet restore --infer-runtimes
publishLocation="$workspace/publish"
rm -rf $publishLocation
publishAppLocation=${publishLocation}/${targetApp}
~/.dotnet/dotnet publish -o $publishAppLocation --configuration release
popd

