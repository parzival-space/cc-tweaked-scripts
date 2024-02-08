@echo off

if "%1"=="--help" (
    echo %0 [project_name]
    exit /b 0
)

set "projectDir=%~dp0"

rem install node dependencies
if not exist "%projectDir%bundler\node_modules" (
    pushd "%projectDir%bundler"
    npm ci
    popd
)

rem run bundler
pushd "%projectDir%bundler"
npm run start "%projectDir%" "%1"
popd
